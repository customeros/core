defmodule Core.Crm.Leads.DailyLeadSummarySender do
  @moduledoc """
  GenServer responsible for sending daily lead summaries to tenants.

  This module:
  * Runs daily at 6am UTC
  * Collects leads created in the past 24 hours that are ICP fit (strong or moderate)
  * Groups leads by tenant
  * Prepares and sends email summaries per tenant
  * Uses cron locking to prevent multiple executions
  * Tracks last execution time to prevent duplicate sends
  """

  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query

  alias Core.Repo
  alias Core.Crm.Leads.Lead
  alias Core.Utils.Tracing
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock
  alias Core.Auth.Users

  # Constants
  @cron_name :cron_daily_lead_summary_sender
  # Duration in minutes after which a lock is considered stuck
  @stuck_lock_duration_minutes 30
  # Check every 5 minutes
  @check_interval_ms 1 * 60 * 1000
  # Minimum time between executions (23 hours and 30 minutes in seconds)
  @min_execution_interval_seconds 23 * 3600 + 30 * 60

  def start_link(opts \\ []) do
    # crons_enabled = Application.get_env(:core, :crons)[:enabled] || false
    crons_enabled = true
    if crons_enabled do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    else
      Logger.info("Daily lead summary sender is disabled (crons disabled)")
      :ignore
    end
  end

  @impl true
  def init(_opts) do
    CronLocks.register_cron(@cron_name)
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_and_send, state) do
    OpenTelemetry.Tracer.with_span "daily_lead_summary_sender.check_and_send" do
      if should_run_now?() do
        lock_uuid = Ecto.UUID.generate()

        case CronLocks.acquire_lock(@cron_name, lock_uuid) do
          %CronLock{} ->
            # Lock acquired, proceed with sending summaries
            process_daily_summaries()
            # Release the lock after processing
            CronLocks.release_lock(@cron_name, lock_uuid)

          nil ->
            # Lock not acquired, try to force release if stuck
            Logger.info(
              "Daily lead summary sender lock not acquired, attempting to release any stuck locks"
            )

            case CronLocks.force_release_stuck_lock(
                   @cron_name,
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
      end

      schedule_check()
      {:noreply, state}
    end
  end

  # Private Functions

  defp should_run_now? do
    now = DateTime.utc_now()

    # Check if it's between 6:00 and 6:30 AM UTC
    time_window_ok = now.hour == 6 and now.minute <= 30

    # Check if enough time has passed since last execution
    time_since_last_execution_ok =
      case CronLocks.get_last_execution_time(@cron_name) do
        nil ->
          true

        last_execution ->
          seconds_since_last = DateTime.diff(now, last_execution)
          seconds_since_last >= @min_execution_interval_seconds
      end

    if time_window_ok and time_since_last_execution_ok do
      Logger.info(
        "Daily lead summary sender will run - within time window and enough time since last execution"
      )

      true
    else
      Logger.debug(
        "Daily lead summary sender skipped - time window: #{time_window_ok}, time since last: #{time_since_last_execution_ok}"
      )

      false
    end
  end

  defp get_today_6am_utc do
    now = DateTime.utc_now()

    date_str =
      "#{now.year}-#{String.pad_leading("#{now.month}", 2, "0")}-#{String.pad_leading("#{now.day}", 2, "0")}"

    {:ok, today_6am} =
      DateTime.new(Date.from_iso8601!(date_str), ~T[06:00:00], "Etc/UTC")

    today_6am
  end

  defp get_yesterday_6am_utc do
    yesterday = Date.add(Date.utc_today(), -1)
    {:ok, yesterday_6am} = DateTime.new(yesterday, ~T[06:00:00], "Etc/UTC")
    yesterday_6am
  end

  defp schedule_check do
    Process.send_after(self(), :check_and_send, @check_interval_ms)
  end

  def process_daily_summaries do
    OpenTelemetry.Tracer.with_span "daily_lead_summary_sender.process_daily_summaries" do
      # Get leads from the past 24 hours that are ICP fit
      leads = fetch_recent_icp_fit_leads()

      # Group leads by tenant
      leads_by_tenant = Enum.group_by(leads, & &1.tenant_id)

      # Process each tenant's leads
      Enum.each(leads_by_tenant, fn {tenant_id, tenant_leads} ->
        process_tenant_leads(tenant_id, tenant_leads)
      end)
    end
  end

  defp fetch_recent_icp_fit_leads do
    yesterday_6am = get_yesterday_6am_utc()
    today_6am = get_today_6am_utc()

    Lead
    |> where([l], l.icp_fit in [:strong, :moderate])
    |> where(
      [l],
      l.inserted_at >= ^yesterday_6am and l.inserted_at < ^today_6am
    )
    |> Repo.all()
  end

  defp process_tenant_leads(tenant_id, leads) do
    OpenTelemetry.Tracer.with_span "daily_lead_summary_sender.process_tenant_leads" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.id", tenant_id},
        {"leads.count", length(leads)}
      ])

      # Get all confirmed users for this tenant
      users = Users.get_users_by_tenant(tenant_id)
      user_emails = Enum.map(users, & &1.email)

      # TODO hardcode user_emails to just one email 'alex@customeros.ai' temporary
      user_emails = ["alex@customeros.ai"]

      if Enum.empty?(user_emails) do
        Logger.info(
          "Skipping daily lead summary for tenant #{tenant_id} - no confirmed users found"
        )
      else
        subject = generate_email_subject(leads)
        body = "Hello, this is a test email"
        from_email = "notification@app.customeros.ai"

        # TODO: Implement email preparation and sending with Postmark
        Logger.info("Preparing daily lead summary for tenant #{tenant_id}",
          tenant_id: tenant_id,
          leads_count: length(leads),
          recipient_count: length(user_emails),
          subject: subject
        )
      end
    end
  end

  defp generate_email_subject(leads) do
    count = length(leads)

    cond do
      count == 1 -> "You have 1 new lead today"
      count > 1 -> "You have #{count} new leads today"
      true -> "No new leads today"
    end
  end
end
