defmodule Core.Integrations.Providers.HubSpot.CompaniesSyncJob do
  @moduledoc """
  GenServer responsible for syncing HubSpot companies.
  """
  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query

  alias Core.Repo
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock
  alias Core.Integrations.Connection

  # 5 minutes
  @default_interval_ms 5 * 60 * 1000
  # 10 companies
  @default_batch_size_per_hubspot_instance 50
  # Duration in minutes after which a lock is considered stuck
  @stuck_lock_duration_minutes 30

  def start_link(opts \\ []) do
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || false

    if crons_enabled do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    else
      Logger.info("HubSpot companies sync job is disabled (crons disabled)")
      :ignore
    end
  end

  @impl true
  def init(_opts) do
    CronLocks.register_cron(:cron_hubspot_company_sync)

    # Schedule the first check
    schedule_check(@default_interval_ms)

    {:ok, %{}}
  end

  @impl true
  def handle_info(:sync_companies, state) do
    OpenTelemetry.Tracer.with_span "hubspot.companies_job.sync_companies" do
      lock_uuid = Ecto.UUID.generate()

      case CronLocks.acquire_lock(:cron_hubspot_company_sync, lock_uuid) do
        %CronLock{} ->
          process_hubspot_connections()

          CronLocks.release_lock(:cron_hubspot_company_sync, lock_uuid)

          schedule_check(@default_interval_ms)

        nil ->
          # Lock not acquired, try to force release if stuck
          Logger.info(
            "HubSpot companies sync job lock not acquired, attempting to release any stuck locks"
          )

          case CronLocks.force_release_stuck_lock(
                 :cron_hubspot_company_sync,
                 @stuck_lock_duration_minutes
               ) do
            :ok ->
              Logger.info(
                "Successfully released stuck lock, will retry acquisition on next run"
              )

            :error ->
              Logger.info("No stuck lock found or could not release it")
          end

          schedule_check(@default_interval_ms)
      end

      {:noreply, state}
    end
  end

  # Schedule the next check
  defp schedule_check(interval_ms) do
    Process.send_after(self(), :sync_companies, interval_ms)
  end

  defp process_hubspot_connections() do
    OpenTelemetry.Tracer.with_span "hubspot.companies_job.process_hubspot_connections" do
      hubspot_connections =
        fetch_hubspot_connections()

      OpenTelemetry.Tracer.set_attributes([
        {"connections.found", length(hubspot_connections)}
      ])

      Enum.each(hubspot_connections, &sync_hubspot_connection/1)
      {:ok, length(hubspot_connections)}
    end
  end

  defp sync_hubspot_connection(hubspot_connection) do
    OpenTelemetry.Tracer.with_span "hubspot.companies_job.sync_hubspot_connection" do
      params = %{
        limit: @default_batch_size_per_hubspot_instance
      }

      final_params =
        if hubspot_connection.company_sync_after do
          Map.put(params, :after, hubspot_connection.company_sync_after)
        else
          params
        end

      Core.Integrations.Providers.HubSpot.Companies.sync_companies(
        hubspot_connection.id,
        final_params,
        false
      )
    end
  end

  defp fetch_hubspot_connections() do
    Connection
    |> where([c], c.provider == :hubspot)
    |> where([c], c.company_sync_completed == false)
    |> limit(@default_batch_size_per_hubspot_instance)
    |> Repo.all()
  end
end
