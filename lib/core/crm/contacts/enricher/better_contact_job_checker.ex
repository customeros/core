defmodule Core.Crm.Contacts.Enricher.BetterContactJobChecker do
  @moduledoc """
  GenServer that periodically checks and processes BetterContact enrichment jobs.

  This module runs as a background process that checks for BetterContact jobs
  ready for retry, processes their results, and updates contact information
  with enriched email and phone data. It implements cron-based scheduling
  with distributed locking to prevent duplicate processing.
  """

  use GenServer
  require Logger

  alias Core.Crm.Contacts
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock
  alias Core.Researcher.EmailValidator
  alias Core.Crm.Contacts.Enricher.BetterContact
  alias Core.Crm.Contacts.Enricher.BetterContactJobs

  @cron :cron_better_contact_job_checker
  @default_interval 60_000
  @stuck_lock_duration 300_000
  @max_attempts 12

  def start_link(_opts) do
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || false

    if crons_enabled do
      GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    else
      Logger.info("BetterContactJobChecker is disabled")
      :ignore
    end
  end

  @impl true
  def init(_) do
    CronLocks.register_cron(@cron)
    schedule_next_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_better_contact_jobs, state) do
    lock_uuid = Ecto.UUID.generate()

    case CronLocks.acquire_lock(@cron, lock_uuid) do
      %CronLock{} ->
        run_cron()
        CronLocks.release_lock(@cron, lock_uuid)

      nil ->
        CronLocks.force_release_stuck_lock(
          @cron,
          @stuck_lock_duration
        )
    end

    schedule_next_check()
    {:noreply, state}
  end

  defp schedule_next_check do
    Process.send_after(self(), :check_better_contact_jobs, @default_interval)
  end

  defp run_cron do
    BetterContactJobs.get_jobs_ready_for_retry()
    |> Enum.each(fn job -> process_job(job) end)
  end

  defp process_job(job_record) do
    case BetterContact.fetch_results(job_record.job_id) do
      {:ok, :processing} ->
        retry_or_fail(job_record)

      {:ok, email, phone_number, response} ->
        update_contact(job_record.contact_id, email, phone_number)
        BetterContactJobs.mark_job_completed_with_response(job_record.job_id, response)

      {:error, reason} ->
        Logger.error("Failed to process BetterContact job", %{
          job_id: job_record.job_id,
          error: reason
        })

        retry_or_fail(job_record)
    end
  end

  defp retry_or_fail(job_record) do
    case job_record.completed_attempts <= @max_attempts do
      true -> BetterContactJobs.schedule_next_retry(job_record)
      false -> BetterContactJobs.mark_job_failed(job_record.job_id)
    end
  end

  defp update_contact(contact_id, _email, _phone_number)
       when is_nil(contact_id),
       do: :ok

  defp update_contact(contact_id, email, phone_number) do
    case email do
      :not_found -> :ok
      _ -> validate_and_update_email(contact_id, email)
    end

    case phone_number do
      :not_found -> :ok
      _ -> update_mobile_number(contact_id, phone_number)
    end
  end

  defp validate_and_update_email(contact_id, email) do
    with {:ok, result} <- EmailValidator.validate_email(email),
         clean_email <- EmailValidator.best_email(result),
         status <- EmailValidator.deliverable_status(result) do
      case EmailValidator.business_email?(result) do
        true ->
          # Save as business email
          Contacts.update_business_email(clean_email, status, contact_id)

        false ->
          # Save as personal email
          Contacts.update_personal_email(clean_email, status, contact_id)
      end
    else
      {:error, reason} ->
        Logger.error("Failed to validate email from BetterContact", %{
          contact_id: contact_id,
          email: email,
          reason: reason
        })

        {:error, reason}
    end
  end

  defp update_mobile_number(phone_number, contact_id) do
    Contacts.update_mobile_phone(contact_id, phone_number)
  end
end
