defmodule Core.Crm.Leads.StageEvaluator do
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
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock
  alias Core.WebTracker.Sessions.Session
  alias Core.Auth.Tenants.Tenant

  @default_interval 10 * 60 * 1000
  @default_batch_size 10
  @stuck_lock_duration_minutes 30
  @delay_between_checks_hours 48
  @delay_from_lead_creation_minutes 60
  # TODO: change to 15
  @session_not_older_than_days 60

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
    CronLocks.register_cron(:cron_stage_evaluator)
    schedule_initial_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_leads_for_stage_evaluation, state) do
    OpenTelemetry.Tracer.with_span "stage_evaluator.check_leads_for_stage_evaluation" do
      lock_uuid = Ecto.UUID.generate()

      case CronLocks.acquire_lock(:cron_stage_evaluator, lock_uuid) do
        %CronLock{} ->
          # Lock acquired, proceed with evaluation
          leads = fetch_target_leads_with_closed_sessions()

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
          CronLocks.release_lock(:cron_stage_evaluator, lock_uuid)

        nil ->
          # Lock not acquired, try to force release if stuck
          Logger.info(
            "Stage evaluator lock not acquired, attempting to release any stuck locks"
          )

          case CronLocks.force_release_stuck_lock(
                 :cron_stage_evaluator,
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
      "StageEvaluator received unexpected message: #{inspect(msg)}"
    )

    {:noreply, state}
  end

  # Private Functions
  defp evaluate_lead(%Lead{} = lead) do
    OpenTelemetry.Tracer.with_span "stage_evaluator.evaluate_lead" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.lead.id", lead.id},
        {"param.tenant.id", lead.tenant_id}
      ])

      Logger.info(
        "Evaluating lead, lead_id: #{lead.id}, attempt: #{lead.icp_fit_evaluation_attempts + 1}"
      )

      case mark_stage_evaluation_attempt(lead) do
        :ok ->
          case get_latest_closed_session_id(lead.tenant_id, lead.ref_id) do
            session_id when is_binary(session_id) ->
              Core.WebTracker.SessionAnalyzer.analyze_session(session_id)
              :ok

            nil ->
              Logger.error("No closed sessions found for lead #{lead.id}")
              {:error, :no_sessions_found}
          end

        {:error, :update_failed} ->
          Tracing.error(
            :update_failed,
            "Failed to mark stage evaluation attempt",
            lead_id: lead.id
          )

          {:error, :update_failed}
      end
    end
  end

  defp mark_stage_evaluation_attempt(%Lead{} = lead) do
    case Repo.update_all(
           from(l in Lead, where: l.id == ^lead.id),
           set: [stage_evaluation_attempt_at: DateTime.utc_now()]
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
    Process.send_after(
      self(),
      :check_leads_for_stage_evaluation,
      @default_interval
    )
  end

  defp schedule_next_check do
    Process.send_after(
      self(),
      :check_leads_for_stage_evaluation,
      @default_interval
    )
  end

  defp get_latest_closed_session_id(tenant_id, company_id) do
    Session
    |> join(:inner, [s], t in Tenant, on: s.tenant == t.name)
    |> where([s, t], t.id == ^tenant_id)
    |> where([s, t], s.company_id == ^company_id)
    |> where([s, t], s.active == false)
    |> order_by([s, t], desc: s.inserted_at)
    |> limit(1)
    |> select([s, t], s.id)
    |> Repo.one()
  end

  defp fetch_target_leads_with_closed_sessions() do
    last_check_cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@delay_between_checks_hours, :hour)

    lead_created_cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@delay_from_lead_creation_minutes, :minute)

    session_not_older_than_cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@session_not_older_than_days, :day)

    Lead
    |> join(:inner, [l], t in Tenant, on: l.tenant_id == t.id)
    |> join(:inner, [l, t], s in Session,
      on: s.company_id == l.ref_id and s.tenant == t.name and s.active == false
    )
    |> where([l, t, s], l.type == :company)
    |> where([l, t, s], l.stage == :target)
    |> where([l, t, s], l.icp_fit in [:moderate, :strong])
    |> where(
      [l, t, s],
      is_nil(l.stage_evaluation_attempt_at) or
        l.stage_evaluation_attempt_at < ^last_check_cutoff
    )
    |> where([l, t, s], l.inserted_at < ^lead_created_cutoff)
    |> where([l, t, s], s.inserted_at > ^session_not_older_than_cutoff)
    |> distinct([l, t, s], l.id)
    |> order_by([l, t, s], asc_nulls_first: l.stage_evaluation_attempt_at)
    |> limit(^@default_batch_size)
    |> select([l, t, s], l)
    |> Repo.all()
  end
end
