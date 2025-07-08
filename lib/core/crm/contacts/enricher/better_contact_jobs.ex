defmodule Core.Crm.Contacts.Enricher.BetterContactJobs do
  @moduledoc """
  Manages BetterContact enrichment job lifecycle and retry logic.

  This module handles the creation, updating, and scheduling of BetterContact
  enrichment jobs. It implements exponential backoff for retries and provides
  functions to mark jobs as completed, failed, or ready for retry.
  """

  import Ecto.Query
  require Logger
  alias Core.Repo
  alias Core.Utils.BackoffCalculator
  alias Core.Crm.Contacts.Enricher.BetterContactJob
  alias Core.Utils.Tracing

  @err_create_job {:error, "failed to create job"}
  @err_update_job {:error, "failed to update job"}
  @err_job_not_found {:error, "job not found"}

  def create_job(job_id, contact_id) do
    attrs = %{
      job_id: job_id,
      contact_id: contact_id,
      status: :processing,
      next_check_at: BackoffCalculator.next_check_time(1)
    }

    result =
      %BetterContactJob{}
      |> BetterContactJob.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, record} ->
        {:ok, record}

      {:error, changeset} ->
        Tracing.error(
          inspect(changeset.errors),
          "Failed to create BetterContact job",
          job_id: job_id,
          contact_id: contact_id
        )

        @err_create_job
    end
  end

  def get_jobs_ready_for_retry do
    now = DateTime.utc_now()

    from(job in BetterContactJob,
      where: job.status == :processing,
      where: job.next_check_at <= ^now,
      order_by: [asc: job.next_check_at]
    )
    |> Repo.all()
  end

  def mark_job_completed(job_id) do
    attrs = %{
      status: :completed,
      next_check_at: nil
    }

    update_job(job_id, attrs)
  end

  def mark_job_failed(job_id) do
    attrs = %{
      status: :failed,
      next_check_at: nil
    }

    update_job(job_id, attrs)
  end

  def schedule_next_retry(%BetterContactJob{} = job) do
    attrs = %{
      status: :processing,
      completed_attempts: job.completed_attempts + 1,
      next_check_at:
        BackoffCalculator.next_check_time(job.completed_attempts + 1)
    }

    update_job(job.job_id, attrs)
  end

  defp update_job(job_id, attrs) do
    case Repo.get_by(BetterContactJob, job_id: job_id) do
      nil ->
        Logger.warning("Attempted to update non-existent job", %{job_id: job_id})

        @err_job_not_found

      job ->
        result =
          job
          |> BetterContactJob.changeset(attrs)
          |> Repo.update()

        case result do
          {:ok, updated_record} ->
            {:ok, updated_record}

          {:error, changeset} ->
            Logger.error("Failed to update BetterContact job", %{
              job_id: job_id,
              errors: inspect(changeset.errors)
            })

            @err_update_job
        end
    end
  end
end
