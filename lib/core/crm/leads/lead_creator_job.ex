defmodule Core.Crm.Leads.LeadCreator do
  @moduledoc """
  Job responsible for creating leads.
  """

  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  alias Core.Crm.Leads
  alias Core.Crm.Leads.LeadDomainQueue
  alias Core.Crm.Companies
  alias Core.Repo
  alias Core.Utils.Tracing
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock

  # 5 minutes in milliseconds
  @default_interval 5 * 60 * 1000
  # Number of leads to process in each run
  @process_batch_size 5
  # Number of records to fetch from database (higher to account for existing leads)
  @fetch_batch_size 50
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

              process_lead_domain_queues_with_balance(lead_domain_queues)

            {:error, :not_found} ->
              OpenTelemetry.Tracer.set_attributes([
                {"domain_queues.count", 0}
              ])

              Logger.info("No domain queues found for processing")

            {:error, :query_failed} ->
              Tracing.error(
                :query_failed,
                "Failed to fetch lead domain queues, will retry on next run"
              )
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

      result =
        with {:ok, db_company} <-
               Companies.get_or_create_by_domain(lead_domain_queue.domain),
             {:ok, lead} <-
               Leads.get_or_create_with_tenant_id(
                 lead_domain_queue.tenant_id,
                 %{
                   type: :company,
                   ref_id: db_company.id
                 }
               ) do
          {:ok, lead}
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

  defp process_lead_domain_queues_with_balance(lead_domain_queues) do
    tenant_groups =
      lead_domain_queues
      |> Enum.group_by(& &1.tenant_id)
      |> Enum.map(fn {tenant_id, records} ->
        sorted_records = Enum.sort_by(records, &(&1.rank || -1), :desc)
        {tenant_id, sorted_records}
      end)
      |> Enum.sort_by(
        fn {_tenant_id, records} ->
          case records do
            [first_record | _] -> first_record.rank || -1
            [] -> -1
          end
        end,
        :desc
      )

    process_round_robin(tenant_groups, 0, [])
  end

  defp process_round_robin([], _created_count, _processed_records), do: :ok

  defp process_round_robin(_tenant_groups, created_count, _processed_records)
       when created_count >= @process_batch_size,
       do: :ok

  defp process_round_robin(tenant_groups, created_count, processed_records) do
    # Take one record from each tenant in order
    {new_processed_records, new_created_count, remaining_tenant_groups} =
      Enum.reduce_while(
        tenant_groups,
        {processed_records, created_count, []},
        fn {tenant_id, records}, {acc_processed, acc_created, acc_remaining} ->
          case records do
            [record | remaining_records] ->
              # Process this record
              result = process_lead_domain_queue(record)

              new_created_count =
                case result do
                  {:ok, %{just_created: true}} -> acc_created + 1
                  _ -> acc_created
                end

              new_processed = [record | acc_processed]

              # Add remaining records back to the list if any
              new_remaining =
                if remaining_records != [],
                  do: [{tenant_id, remaining_records} | acc_remaining],
                  else: acc_remaining

              # Stop if we've created enough leads
              if new_created_count >= @process_batch_size do
                {:halt, {new_processed, new_created_count, new_remaining}}
              else
                {:cont, {new_processed, new_created_count, new_remaining}}
              end

            [] ->
              # No more records for this tenant, skip
              {:cont, {acc_processed, acc_created, acc_remaining}}
          end
        end
      )

    # Continue with remaining tenant groups
    process_round_robin(
      remaining_tenant_groups,
      new_created_count,
      new_processed_records
    )
  end

  defp mark_as_processed(%LeadDomainQueue{} = lead_domain_queue) do
    lead_domain_queue
    |> Ecto.Changeset.change(%{
      processed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
    |> case do
      {:ok, _updated} ->
        :ok

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
    query = """
    WITH ranked_records AS (
      SELECT id, tenant_id, domain, rank, processed_at, inserted_at,
             ROW_NUMBER() OVER (
               PARTITION BY tenant_id
               ORDER BY COALESCE(rank, -1) DESC, inserted_at ASC
             ) as tenant_rank
      FROM lead_domain_queues
      WHERE processed_at IS NULL
    )
    SELECT id, tenant_id, domain, rank, processed_at, inserted_at
    FROM ranked_records
    WHERE tenant_rank <= #{max(2, div(@fetch_batch_size, 10))}
    ORDER BY COALESCE(rank, -1) DESC, tenant_rank ASC
    LIMIT #{@fetch_batch_size}
    """

    case Repo.query(query) do
      {:ok, %{rows: rows, columns: _columns}} ->
        records =
          Enum.map(rows, fn row ->
            # Convert row to struct with proper field mapping
            [id, tenant_id, domain, rank, processed_at, inserted_at] = row

            %LeadDomainQueue{
              id: id,
              tenant_id: tenant_id,
              domain: domain,
              rank: rank,
              processed_at: processed_at,
              inserted_at: inserted_at
            }
          end)

        case records do
          [] -> {:error, :not_found}
          records -> {:ok, records}
        end

      {:error, reason} ->
        Tracing.error(reason, "Failed to fetch lead domain queues")
        {:error, :query_failed}
    end
  end
end
