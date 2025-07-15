defmodule Core.Analytics.GoogleAds.CampaignsDailyFetcher do
  @moduledoc """
  GenServer responsible for syncing Google Ads campaign data for all tenants.

  This module:
  * Runs daily at 12:00 UTC
  * Fetches campaign data for all tenants with Google Ads connections
  * Updates or creates campaign records in the database
  * Uses cron locking to prevent multiple executions
  * Tracks last execution time to prevent duplicate syncs
  """

  use GenServer
  require Logger
  require OpenTelemetry.Tracer

  alias Core.Repo
  alias Core.Analytics.GoogleAds.GoogleAdsCampaign
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock
  alias Core.Utils.Tracing
  alias Core.Integrations.Registry
  alias Core.Integrations.Providers.GoogleAds.{Campaigns, Customers}

  @cron_name :cron_google_ads_campaign_fetcher
  @stuck_lock_duration_minutes 30
  # TODO alexb: set to 5 minutes (5 * 60 * 1000)
  @check_interval_ms 5 * 5 * 1000
  # 23.5 hours in seconds
  @min_execution_interval_seconds 23 * 3600 + 30 * 60

  def start_link(opts \\ []) do
    # TODO alexb: set to false
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || true

    if crons_enabled do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    else
      Logger.info("Google Ads campaign sync job is disabled (crons disabled)")
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
  def handle_info(:check_and_sync, state) do
    OpenTelemetry.Tracer.with_span "google_ads_campaign_sync.check_and_sync" do
      if should_run_now?() do
        lock_uuid = Ecto.UUID.generate()

        case CronLocks.acquire_lock(@cron_name, lock_uuid) do
          %CronLock{} ->
            # Lock acquired, proceed with syncing campaigns
            process_campaign_sync()
            # Release the lock after processing
            CronLocks.release_lock(@cron_name, lock_uuid)

          nil ->
            # Lock not acquired, try to force release if stuck
            Logger.info(
              "Google Ads campaign sync lock not acquired, attempting to release any stuck locks"
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

    # Check if it's between 12:00 and 12:20 UTC
    time_window_ok = now.hour == 12 and now.minute <= 20

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
        "Google Ads campaign sync will run - within time window and enough time since last execution"
      )

      true
    else
      Logger.debug(
        "Google Ads campaign sync skipped - time window: #{time_window_ok}, time since last: #{time_since_last_execution_ok}"
      )

      false
    end
  end

  defp schedule_check do
    Process.send_after(self(), :check_and_sync, @check_interval_ms)
  end

  defp process_campaign_sync do
    OpenTelemetry.Tracer.with_span "google_ads_campaign_sync.process_campaign_sync" do
      # Get all tenants with Google Ads connections
      Registry.list_connections(:google_ads)
      |> Enum.each(fn connection ->
        sync_tenant_campaigns(connection)
      end)
    end
  end

  defp sync_tenant_campaigns(connection) do
    OpenTelemetry.Tracer.with_span "google_ads_campaign_sync.sync_tenant_campaigns" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.id", connection.tenant_id},
        {"manager_customer_id", connection.external_system_id}
      ])

      case Customers.list_accessible_customers(connection) do
        {:ok, clients} ->
          Logger.info(
            "Found #{length(clients)} Google Ads client accounts for tenant #{connection.tenant_id}"
          )

          # Get campaigns for each client account
          Enum.each(clients, fn client ->
            sync_client_campaigns(connection, client)
          end)

        {:error, reason} ->
          Tracing.error(reason, "Failed to get Google Ads client accounts",
            tenant_id: connection.tenant_id,
            manager_customer_id: connection.external_system_id
          )
      end
    end
  end

  defp sync_client_campaigns(connection, client) do
    OpenTelemetry.Tracer.with_span "google_ads_campaign_sync.sync_client_campaigns" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.id", connection.tenant_id},
        {"manager_customer_id", connection.external_system_id},
        {"client_customer_id", client["id"]}
      ])

      case Campaigns.list_campaigns_for_customer(connection, client["id"]) do
        {:ok, campaigns} ->
          Logger.info(
            "Found #{length(campaigns)} campaigns for client account #{client["id"]} (tenant: #{connection.tenant_id})"
          )

          Enum.each(campaigns, fn campaign ->
            upsert_campaign(
              connection.tenant_id,
              connection.external_system_id,
              client["id"],
              campaign
            )
          end)

        {:error, reason} ->
          Tracing.error(reason, "Failed to fetch Google Ads campaigns",
            tenant_id: connection.tenant_id,
            manager_customer_id: connection.external_system_id,
            client_customer_id: client["id"]
          )
      end
    end
  end

  defp upsert_campaign(
         tenant_id,
         manager_customer_id,
         client_customer_id,
         campaign_data
       ) do
    OpenTelemetry.Tracer.with_span "google_ads_campaign_sync.upsert_campaign" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.id", tenant_id},
        {"manager_customer_id", manager_customer_id},
        {"client_customer_id", client_customer_id},
        {"campaign.id", campaign_data["id"]}
      ])

      # Convert dates from string to Date if they're not nil
      start_date =
        if campaign_data["start_date"],
          do: Date.from_iso8601!(campaign_data["start_date"])

      end_date =
        if campaign_data["end_date"],
          do: Date.from_iso8601!(campaign_data["end_date"])

      attrs = %{
        tenant_id: tenant_id,
        manager_customer_id: manager_customer_id,
        client_customer_id: client_customer_id,
        campaign_id: campaign_data["id"],
        name: campaign_data["name"],
        status: campaign_data["status"],
        advertising_channel_type: campaign_data["advertising_channel_type"],
        advertising_channel_sub_type:
          campaign_data["advertising_channel_sub_type"],
        start_date: start_date,
        end_date: end_date,
        optimization_score: campaign_data["optimization_score"],
        raw_data: campaign_data
      }

      # Try to find existing campaign
      case Repo.get_by(GoogleAdsCampaign, %{
             tenant_id: tenant_id,
             manager_customer_id: manager_customer_id,
             client_customer_id: client_customer_id,
             campaign_id: campaign_data["id"]
           }) do
        nil ->
          # Create new campaign
          %GoogleAdsCampaign{}
          |> GoogleAdsCampaign.changeset(attrs)
          |> Repo.insert()
          |> case do
            {:ok, _campaign} ->
              Logger.info("Created new Google Ads campaign",
                tenant_id: tenant_id,
                campaign_id: campaign_data["id"]
              )

            {:error, reason} ->
              Tracing.error(reason, "Failed to create Google Ads campaign",
                tenant_id: tenant_id,
                campaign_id: campaign_data["id"]
              )
          end

        existing_campaign ->
          # Update existing campaign
          existing_campaign
          |> GoogleAdsCampaign.upsert_changeset(attrs)
          |> Repo.update()
          |> case do
            {:ok, _campaign} ->
              Logger.info("Updated Google Ads campaign #{campaign_data["id"]}")

            {:error, reason} ->
              Tracing.error(reason, "Failed to update Google Ads campaign",
                tenant_id: tenant_id,
                campaign_id: campaign_data["id"]
              )
          end
      end
    end
  end
end
