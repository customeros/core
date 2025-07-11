defmodule Core.Analytics.AnalyticsJobs do
  import Ecto.Query

  require Logger

  alias Core.Repo
  alias Core.Utils.Tracing
  alias Core.Analytics.AnalyticsJob

  @err_create_job {:error, "failed to create analytics job"}
  @err_not_found {:error, "job not found"}

  def create_job(tenant_id, job_type, scheduled_for_utc) do
    %{
      tenant_id: tenant_id,
      job_type: job_type,
      scheduled_at: scheduled_for_utc
    }
    |> AnalyticsJob.changeset()
    |> Repo.insert()
    |> case do
      {:ok, record} ->
        {:ok, record}

      {:error, changeset} ->
        Tracing.error(
          inspect(changeset.errors),
          "Failed to create analytics job",
          tenant_id: tenant_id,
          job_type: job_type,
          scheduled_for_utc: scheduled_for_utc
        )

        @err_create_job
    end
  end

  def get_by_id(job_id) do
    case Repo.get_by(AnalyticsJob, id: job_id) do
      nil -> @err_not_found
      %AnalyticsJob{} = job -> {:ok, job}
    end
  end

  def get_ready_jobs do
    now = DateTime.utc_now()

    from(j in AnalyticsJob,
      where: j.status in [:pending, :failed] and j.scheduled_at <= ^now,
      order_by: [asc: j.scheduled_at]
    )
    |> Repo.all()
  end

  def job_exists?(tenant_id, job_type, scheduled_for_utc) do
    target_hour = %{
      scheduled_for_utc
      | minute: 0,
        second: 0,
        microsecond: {0, 0}
    }

    query =
      from j in AnalyticsJob,
        where:
          j.tenant_id == ^tenant_id and
            j.job_type == ^job_type and
            fragment("date_trunc('hour', ?)", j.scheduled_at) == ^target_hour

    Repo.exists?(query)
  end

  def cleanup(days_to_keep \\ 14) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_to_keep, :day)

    {deleted_count, _} =
      from(j in AnalyticsJob,
        where:
          j.status in [:completed, :failed] and j.inserted_at < ^cutoff_date
      )
      |> Repo.delete_all()

    Logger.info("Cleaned up #{deleted_count} old analytics jobs")
    {:ok, deleted_count}
  end

  def mark_completed(%AnalyticsJob{} = job) do
    job
    |> AnalyticsJob.changeset(%{status: :completed})
    |> Repo.update()
  end

  def mark_failed(%AnalyticsJob{} = job) do
    job
    |> AnalyticsJob.changeset(%{status: :failed})
    |> Repo.update()
  end
end
