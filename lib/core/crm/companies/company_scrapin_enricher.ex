defmodule Core.Crm.Companies.CompanyScrapinEnricher do
  @moduledoc """
  GenServer responsible for periodically enriching company data using Scrapin.
  """
  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query

  alias Core.Repo
  alias Core.Crm.Companies.Company
  alias Core.Crm.Companies.CompanyScrapinEnrich
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock

  # 10 seconds
  @default_interval_ms 10 * 1000
  # 5 minutes
  @long_interval_ms 5 * 60 * 1000
  # 50 companies
  @default_batch_size 50
  # Duration in minutes after which a lock is considered stuck
  @stuck_lock_duration_minutes 30

  def start_link(opts \\ []) do
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || false

    if crons_enabled do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    else
      Logger.info("Company scrapin enricher is disabled (crons disabled)")
      :ignore
    end
  end

  @impl true
  def init(_opts) do
    CronLocks.register_cron(:cron_company_scrapin_enricher)

    # Schedule the first check
    schedule_check(@default_interval_ms)

    {:ok, %{}}
  end

  @impl true
  def handle_info(:enrich_companies, state) do
    OpenTelemetry.Tracer.with_span "company_scrapin_enricher.enrich_companies" do
      lock_uuid = Ecto.UUID.generate()

      case CronLocks.acquire_lock(:cron_company_scrapin_enricher, lock_uuid) do
        %CronLock{} ->
          # Lock acquired, proceed with enrichment
          {_, num_companies} = enrich_companies_with_scrapin()

          # Release the lock after processing
          CronLocks.release_lock(:cron_company_scrapin_enricher, lock_uuid)

          next_interval_ms =
            if num_companies == @default_batch_size do
              @default_interval_ms
            else
              @long_interval_ms
            end

          schedule_check(next_interval_ms)

        nil ->
          # Lock not acquired, try to force release if stuck
          Logger.info(
            "Company enricher lock not acquired, attempting to release any stuck locks"
          )

          case CronLocks.force_release_stuck_lock(
                 :cron_company_scrapin_enricher,
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

  # Handle unexpected messages (like task results) gracefully
  @impl true
  def handle_info(message, state) do
    Logger.warning(
      "CompanyScrapinEnricher received unexpected message: #{inspect(message)}"
    )

    {:noreply, state}
  end

  # Schedule the next check
  defp schedule_check(interval_ms) do
    Process.send_after(self(), :enrich_companies, interval_ms)
  end

  defp enrich_companies_with_scrapin() do
    OpenTelemetry.Tracer.with_span "company_scrapin_enricher.enrich_companies_with_scrapin" do
      companies_for_scrapin_enrichment =
        fetch_companies_for_scrapin_enrichment(@default_batch_size)

      OpenTelemetry.Tracer.set_attributes([
        {"companies.found", length(companies_for_scrapin_enrichment)},
        {"batch.size", @default_batch_size}
      ])

      # Enrich each company's icon
      Enum.each(companies_for_scrapin_enrichment, &enrich_company_scrapin/1)
      {:ok, length(companies_for_scrapin_enrichment)}
    end
  end

  defp enrich_company_scrapin(company) do
    CompanyScrapinEnrich.enrich(company.id)
  end

  @spec fetch_companies_for_scrapin_enrichment(integer()) :: [Company.t()]
  defp fetch_companies_for_scrapin_enrichment(batch_size) do
    hours_ago_48 = DateTime.add(DateTime.utc_now(), -48 * 60 * 60)
    minutes_ago_10 = DateTime.add(DateTime.utc_now(), -10 * 60)
    max_attempts = 5

    Company
    |> where(
      [c],
      is_nil(c.name) or
        is_nil(c.city) or
        is_nil(c.region) or
        is_nil(c.country_a2) or
        is_nil(c.employee_count)
    )
    |> where([c], c.scrapin_enrichment_attempts < ^max_attempts)
    |> where(
      [c],
      is_nil(c.scrapin_enrich_attempt_at) or
        c.scrapin_enrich_attempt_at < ^hours_ago_48
    )
    |> where([c], c.inserted_at < ^minutes_ago_10)
    |> order_by([c], asc_nulls_first: c.scrapin_enrich_attempt_at)
    |> limit(^batch_size)
    |> Repo.all()
  end
end
