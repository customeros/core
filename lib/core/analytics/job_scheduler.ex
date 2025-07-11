defmodule Core.Analytics.JobScheduler do
  @moduledoc """
  Analytics job scheduler module.

  This module is responsible for scheduling analytics jobs for all tenants:
  - Schedules hourly lead generation aggregation jobs for the next 24 hours
  - Prevents duplicate job creation by checking existing jobs
  - Distributes job scheduling across tenants
  - Adds random minute offsets to prevent job clustering

  Works with the analytics job processor to ensure timely data aggregation.
  """

  require Logger

  alias Core.Auth.Tenants
  alias Core.Analytics.AnalyticsJobs

  def schedule_future_jobs do
    Logger.info("Scheduling all analytics jobs for the next 24 hours...")

    case Tenants.get_all_tenant_ids() do
      {:error, reason} ->
        Logger.error("Failed to get tenant ids: #{reason}")
        {:error, reason}

      {:ok, tenant_ids} ->
        Enum.each(tenant_ids, fn tenant_id ->
          schedule_jobs_for_tenant(tenant_id)
        end)
    end
  end

  ### Schedules all jobs for the next 24 hours
  defp schedule_jobs_for_tenant(tenant_id) do
    now = DateTime.utc_now()
    start_time = next_job_time(now)

    job_times =
      0..23
      |> Enum.map(fn hours_ahead ->
        DateTime.add(start_time, hours_ahead, :hour)
      end)

    Enum.each(job_times, fn scheduled_time ->
      unless AnalyticsJobs.job_exists?(
               tenant_id,
               :hourly_lead_generation_agg,
               scheduled_time
             ) do
        case AnalyticsJobs.create_job(
               tenant_id,
               :hourly_lead_generation_agg,
               scheduled_time
             ) do
          {:ok, _job} ->
            Logger.info(
              "Scheduled job for tenant #{tenant_id} at #{DateTime.to_iso8601(scheduled_time)}"
            )

          {:error, reason} ->
            Logger.error(
              "Failed to schedule job for tenant #{tenant_id}: #{inspect(reason)}"
            )
        end
      end
    end)
  end

  defp next_job_time(datetime_utc) do
    dt =
      case datetime_utc do
        %DateTime{} = dt ->
          dt

        _ ->
          Logger.warning(
            "Invalid datetime received: #{inspect(datetime_utc)}, using current time"
          )

          DateTime.utc_now()
      end

    dt
    |> DateTime.truncate(:second)
    |> Map.put(:minute, 0)
    |> Map.put(:second, 0)
    |> DateTime.add(1, :hour)
    |> DateTime.add(:rand.uniform(10), :minute)
  end
end
