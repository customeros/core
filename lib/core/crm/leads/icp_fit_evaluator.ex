defmodule Core.Crm.Leads.IcpFitEvaluator do
  @moduledoc """
  GenServer responsible for evaluating and setting proper stages for leads.

  This module:
  * Monitors leads that need stage evaluation
  """

  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query
  alias Core.Crm.Leads
  alias Core.Crm.Leads.Lead
  alias Core.Repo
  alias Core.Utils.Tracing
  alias Core.Crm.Leads.NewLeadPipeline
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock

  # Constants
  @default_interval 2 * 60 * 1000
  @default_batch_size 5
  @stuck_lock_duration_minutes 30
  @max_attempts 5
  @delay_between_checks_hours 12
  @delay_from_lead_creation_minutes 30

  @doc """
  Starts the stage evaluator process.
  """
  def start_link(_opts) do
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || false

    if crons_enabled do
      GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    else
      Logger.info("Stage evaluator is disabled (crons disabled)")
      :ignore
    end
  end

  # Server Callbacks

  @impl true
  def init(_) do
    CronLocks.register_cron(:cron_icp_fit_evaluator)
    schedule_initial_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_pending_leads, state) do
    OpenTelemetry.Tracer.with_span "icp_fit_evaluator.check_pending_leads" do
      lock_uuid = Ecto.UUID.generate()

      case CronLocks.acquire_lock(:cron_icp_fit_evaluator, lock_uuid) do
        %CronLock{} ->
          # Lock acquired, proceed with evaluation
          leads = fetch_leads_for_icp_fit_evaluation()

          OpenTelemetry.Tracer.set_attributes([
            {"batch_size", @default_batch_size},
            {"leads.count", length(leads)}
          ])

          Enum.each(leads, fn lead ->
            case Leads.get_by_id(lead.tenant_id, lead.id) do
              {:ok, lead} ->
                evaluate_lead(lead)

              {:error, :not_found} ->
                Logger.error("Lead not found for evaluation: #{lead.id}",
                  reason: :not_found
                )

                Tracing.error(:not_found)
            end
          end)

          # Release the lock after processing
          CronLocks.release_lock(:cron_icp_fit_evaluator, lock_uuid)

        nil ->
          # Lock not acquired, try to force release if stuck
          Logger.info(
            "ICP fit evaluator lock not acquired, attempting to release any stuck locks"
          )

          case CronLocks.force_release_stuck_lock(
                 :cron_icp_fit_evaluator,
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

  @impl true
  def handle_info(msg, state) do
    Logger.warning(
      "IcpFitEvaluator received unexpected message: #{inspect(msg)}"
    )

    {:noreply, state}
  end

  # Private Functions
  defp evaluate_lead(%Lead{} = lead) do
    OpenTelemetry.Tracer.with_span "icp_fit_evaluator.evaluate_lead" do
      OpenTelemetry.Tracer.set_attributes([
        {"lead.id", lead.id},
        {"tenant.id", lead.tenant_id}
      ])

      Logger.info(
        "Evaluating lead, lead_id: #{lead.id}, attempt: #{lead.icp_fit_evaluation_attempts + 1}"
      )

      case mark_icp_fit_evaluation_attempt(lead) do
        :ok ->
          case NewLeadPipeline.start(lead.id, lead.tenant_id) do
            {:ok, _} ->
              Tracing.ok()
              :ok
          end

        {:error, :update_failed} ->
          Tracing.error(
            :update_failed,
            "Failed to mark ICP fit attempt",
            lead_id: lead.id
          )

          {:error, :update_failed}
      end
    end
  end

  defp mark_icp_fit_evaluation_attempt(%Lead{} = lead) do
    case Repo.update_all(
           from(l in Lead, where: l.id == ^lead.id),
           set: [icp_fit_evaluation_attempt_at: DateTime.utc_now()],
           inc: [icp_fit_evaluation_attempts: 1]
         ) do
      {0, _} ->
        Tracing.error(
          :update_failed,
          "Failed to mark attempt for lead #{lead.id}",
          lead_id: lead.id
        )
        {:error, :update_failed}

      {_count, _} ->
        :ok
    end
  end

  defp schedule_initial_check do
    Process.send_after(self(), :check_pending_leads, @default_interval)
  end

  defp schedule_next_check do
    Process.send_after(self(), :check_pending_leads, @default_interval)
  end

  defp fetch_leads_for_icp_fit_evaluation() do
    last_check_cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@delay_between_checks_hours, :hour)

    created_cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@delay_from_lead_creation_minutes, :minute)

    Lead
    |> where([l], l.type == :company)
    |> where([l], is_nil(l.icp_fit))
    |> where([l], l.icp_fit_evaluation_attempts < ^@max_attempts)
    |> where(
      [l],
      is_nil(l.icp_fit_evaluation_attempt_at) or
        l.icp_fit_evaluation_attempt_at < ^last_check_cutoff
    )
    |> where([l], l.inserted_at < ^created_cutoff)
    |> order_by([l], asc_nulls_first: l.icp_fit_evaluation_attempt_at)
    |> limit(^@default_batch_size)
    |> Repo.all()
  end
end
