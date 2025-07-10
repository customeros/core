defmodule Core.Analytics.JobProcessor do
  use GenServer
  require Logger

  alias Core.Utils.CronLocks
  alias Core.Analytics.Builder
  alias Core.Utils.Cron.CronLock
  alias Core.Analytics.JobScheduler
  alias Core.Analytics.AnalyticsJob
  alias Core.Analytics.AnalyticsJobs

  @cron :cron_analytics_processor
  @stuck_lock_duration_minutes 30

  def start_link(_opts) do
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || false

    if crons_enabled do
      GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    else
      Logger.info("AnalyticsProcessor is disabled")
      :ignore
    end
  end

  def init(_) do
    CronLocks.register_cron(@cron)
    send(self(), :schedule_jobs)
    send(self(), :process_jobs)
    send(self(), :cleanup_jobs)
    {:ok, %{}}
  end

  def handle_info(:process_jobs, state) do
    Logger.info("Processing analytics jobs...")

    lock_uuid = Ecto.UUID.generate()

    case CronLocks.acquire_lock(@cron, lock_uuid) do
      %CronLock{} ->
        process_jobs()
        CronLocks.release_lock(@cron, lock_uuid)

      nil ->
        CronLocks.force_release_stuck_lock(
          @cron,
          @stuck_lock_duration_minutes
        )
    end

    schedule_next_check(:process_jobs, :timer.minutes(10))
    {:noreply, state}
  end

  def handle_info(:schedule_jobs, state) do
    Logger.info("Scheduling analytics jobs...")

    lock_uuid = Ecto.UUID.generate()

    case CronLocks.acquire_lock(@cron, lock_uuid) do
      %CronLock{} ->
        JobScheduler.schedule_future_jobs()
        CronLocks.release_lock(@cron, lock_uuid)

      nil ->
        CronLocks.force_release_stuck_lock(
          @cron,
          @stuck_lock_duration_minutes
        )
    end

    schedule_next_check(:schedule_jobs, :timer.hours(4))
    {:noreply, state}
  end

  def handle_info(:cleanup_jobs, state) do
    Logger.info("Cleaning up analytics jobs...")

    lock_uuid = Ecto.UUID.generate()

    case CronLocks.acquire_lock(@cron, lock_uuid) do
      %CronLock{} ->
        AnalyticsJobs.cleanup()
        CronLocks.release_lock(@cron, lock_uuid)

      nil ->
        CronLocks.force_release_stuck_lock(
          @cron,
          @stuck_lock_duration_minutes
        )
    end

    schedule_next_check(:cleanup_jobs, :timer.hours(24))
    {:noreply, state}
  end

  defp schedule_next_check(msg, interval) do
    Process.send_after(self(), msg, interval)
  end

  defp process_jobs do
    jobs = AnalyticsJobs.get_ready_jobs()

    Enum.each(jobs, fn job ->
      execute_job(job)
    end)
  end

  defp execute_job(%AnalyticsJob{job_type: :hourly_lead_generation_agg} = job) do
    Logger.info("Processing job #{job.id} for tenant #{job.tenant_id}")

    start_hour = truncate_to_hour(DateTime.add(job.scheduled_at, -1, :hour))

    case Builder.build_hourly_aggregate_stats(job.tenant_id, start_hour) do
      {:ok, _data} ->
        AnalyticsJobs.mark_completed(job)
        Logger.info("Successfully completed job #{job.id}")

      {:error, reason} ->
        AnalyticsJobs.mark_failed(job)
        Logger.error("Analytics job execution failed: #{inspect(reason)}")
    end
  end

  defp truncate_to_hour(%DateTime{} = dt) do
    %{dt | minute: 0, second: 0, microsecond: {0, 0}}
  end
end
