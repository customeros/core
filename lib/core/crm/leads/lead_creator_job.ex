defmodule Core.Crm.Leads.LeadCreator do
  @moduledoc """
  Job responsible for creating leads.
  """

  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query
  alias Core.Crm.Leads
  alias Core.Crm.Leads.LeadDomainQueue
  alias Core.Crm.Companies
  alias Core.Repo
  alias Core.Utils.Tracing
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock

  # 5 minutes in milliseconds
  @default_interval 5 * 60 * 1000
  # Number of leads to process in each batch
  @default_batch_size 5
  # Duration in minutes after which a lock is considered stuck
  @stuck_lock_duration_minutes 30

  @doc """
  Starts the stage evaluator process.
  """
  def start_link(_opts) do
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || false

    if crons_enabled do
      GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    else
      Logger.info("Lead creator is disabled (crons disabled)")
      :ignore
    end
  end

  # Server Callbacks

  @impl true
  def init(_) do
    CronLocks.register_cron(:cron_lead_creator)
    schedule_initial_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_lead_domain_queues, state) do
    OpenTelemetry.Tracer.with_span "lead_creator.check_leads" do
      lock_uuid = Ecto.UUID.generate()

              case CronLocks.acquire_lock(:cron_lead_creator, lock_uuid) do
          %CronLock{} ->
            case fetch_lead_domain_queues_to_process() do
              {:ok, lead_domain_queues} ->
                OpenTelemetry.Tracer.set_attributes([
                  {"lead_domain_queues.count", length(lead_domain_queues)}
                ])

                Enum.each(lead_domain_queues, fn lead_domain_queue ->
                  process_lead_domain_queue(lead_domain_queue)
                end)

              {:error, :not_found} ->
                OpenTelemetry.Tracer.set_attributes([
                  {"domain_queues.count", 0}
                ])

                Logger.info("No domain queues found for processing")
            end

          CronLocks.release_lock(:cron_lead_creator, lock_uuid)

        nil ->
          # Lock not acquired, try to force release if stuck
          Logger.info(
            "Lead creator lock not acquired, attempting to release any stuck locks"
          )

          case CronLocks.force_release_stuck_lock(
                 :cron_lead_creator,
                 @stuck_lock_duration_minutes
               ) do
            :ok ->
              Logger.info(
                "Successfully released stuck lock, will retry acquisition on next run"
              )

            :error ->
              Logger.info("No stuck lock found or could not release it")
          end
      end

      schedule_next_check()
      {:noreply, state}
    end
  end

  # Private Functions
  defp process_lead_domain_queue(%LeadDomainQueue{} = lead_domain_queue) do
    OpenTelemetry.Tracer.with_span "lead_creator.process_domain" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.domain", lead_domain_queue.domain},
        {"param.tenant_id", lead_domain_queue.tenant_id}
      ])

      result = with {:ok, db_company} <- Companies.get_or_create_by_domain(lead_domain_queue.domain),
                   {:ok, _lead} <-
                     Leads.get_or_create_with_tenant_id(lead_domain_queue.tenant_id, %{
                       type: :company,
                       ref_id: db_company.id
                     }) do
        {:ok, db_company}
      else
        {:error, reason} ->
          Tracing.error(reason, "Failed to process domain queue record",
            company_domain: lead_domain_queue.domain,
            tenant_id: lead_domain_queue.tenant_id
          )
          {:error, reason}
      end

      # Always mark as processed regardless of result
      mark_as_processed(lead_domain_queue)

      result
    end
  end

  defp mark_as_processed(%LeadDomainQueue{} = lead_domain_queue) do
    lead_domain_queue
    |> Ecto.Changeset.change(%{processed_at: DateTime.utc_now()})
    |> Repo.update()
    |> case do
      {:ok, _updated} -> :ok
      {:error, reason} ->
        Logger.error("Failed to mark domain queue record as processed",
          id: lead_domain_queue.id,
          reason: reason
        )
        :error
    end
  end

  defp schedule_initial_check do
    Process.send_after(self(), :check_lead_domain_queues, @default_interval)
  end

  defp schedule_next_check do
    Process.send_after(self(), :check_lead_domain_queues, @default_interval)
  end

  defp fetch_lead_domain_queues_to_process() do
    LeadDomainQueue
    |> where([l], is_nil(l.processed_at))
    |> order_by([l], [desc: l.rank, asc: l.inserted_at])
    |> limit(^@default_batch_size)
    |> Repo.all()
    |> then(fn
      [] -> {:error, :not_found}
      leads -> {:ok, leads}
    end)
  end
end
