defmodule Core.Crm.Companies.CompanyEnricher do
  @moduledoc """
  GenServer responsible for periodically enriching company data.
  Runs every 15 minutes and processes companies that need enrichment for various fields:
  - Icon
  - Industry
  - Name
  - Country

  Configuration:
  - Uses general cron configuration from :core, :crons, :enabled
  - Other settings (interval_ms, batch_size) are configured in config.exs
  """
  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query

  alias Core.Repo
  alias Core.Crm.Companies.Company
  alias Core.Crm.Companies.CompanyEnrich
  alias Core.Utils.Tracing

  # 1 minute
  @default_interval_ms 60 * 1000
  # 15 minutes
  @long_interval_ms 15 * 60 * 1000
  @default_batch_size 10

  def start_link(opts \\ []) do
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || false

    if crons_enabled do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    else
      Logger.info("Company enricher is disabled (crons disabled)")
      :ignore
    end
  end

  @impl true
  def init(_opts) do
    # Schedule the first check
    schedule_check(@default_interval_ms)

    {:ok, %{}}
  end

  @impl true
  def handle_info(:enrich_companies, state) do
    OpenTelemetry.Tracer.with_span "company_enricher.enrich_companies" do
      {_, numCompaniesForIconEnrichment} = enrich_companies_icon()
      {_, numCompaniesForIndustryEnrichment} = enrich_companies_industry()
      {_, numCompaniesForNameEnrichment} = enrich_companies_name()
      {_, numCompaniesForCountryEnrichment} = enrich_companies_country()

      # Schedule the next check - use default interval if either enrichment hit the batch size
      next_interval_ms =
        if numCompaniesForIconEnrichment == @default_batch_size or
             numCompaniesForNameEnrichment == @default_batch_size or
             numCompaniesForCountryEnrichment == @default_batch_size or
             numCompaniesForIndustryEnrichment == @default_batch_size do
          @default_interval_ms
        else
          @long_interval_ms
        end

      schedule_check(next_interval_ms)

      {:noreply, state}
    end
  end

  # Schedule the next check
  defp schedule_check(interval_ms) do
    Process.send_after(self(), :enrich_companies, interval_ms)
  end

  defp enrich_companies_icon() do
    OpenTelemetry.Tracer.with_span "company_enricher.enrich_companies_icon" do
      companiesForIconEnrichment =
        fetch_companies_for_icon_enrichment(@default_batch_size)

      OpenTelemetry.Tracer.set_attributes([
        {"companies.found", length(companiesForIconEnrichment)},
        {"batch.size", @default_batch_size}
      ])

      # Enrich each company's icon
      Enum.each(companiesForIconEnrichment, &enrich_company_icon/1)
      {:ok, length(companiesForIconEnrichment)}
    end
  end

  defp enrich_company_icon(company) do
    OpenTelemetry.Tracer.with_span "company_enricher.enrich_icon" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      case CompanyEnrich.enrich_icon(company.id) do
        :ok ->
          Tracing.ok
          :ok

        {:error, reason} ->
          Tracing.error(inspect(reason))

          Logger.error(
            "Failed to start icon enrichment for company: #{company.id} (domain: #{company.primary_domain}), reason: #{inspect(reason)}"
          )

          {:error, reason}
      end
    end
  end

  @spec fetch_companies_for_icon_enrichment(integer()) :: [Company.t()]
  defp fetch_companies_for_icon_enrichment(batch_size) do
    hours_ago_24 = DateTime.add(DateTime.utc_now(), -24 * 60 * 60)
    minutes_ago_10 = DateTime.add(DateTime.utc_now(), -10 * 60)
    max_attempts = 5

    Company
    |> where([c], is_nil(c.icon_key) or c.icon_key == "")
    |> where([c], c.icon_enrichment_attempts < ^max_attempts)
    |> where(
      [c],
      is_nil(c.icon_enrich_attempt_at) or
        c.icon_enrich_attempt_at < ^hours_ago_24
    )
    |> where([c], c.inserted_at < ^minutes_ago_10)
    |> order_by([c], asc: c.icon_enrich_attempt_at)
    |> limit(^batch_size)
    |> Repo.all()
  end

  defp enrich_companies_industry() do
    OpenTelemetry.Tracer.with_span "company_enricher.enrich_companies_industry" do
      companiesForIndustryEnrichment =
        fetch_companies_for_industry_enrichment(@default_batch_size)

      OpenTelemetry.Tracer.set_attributes([
        {"companies.found", length(companiesForIndustryEnrichment)},
        {"batch.size", @default_batch_size}
      ])

      # Enrich each company's icon
      Enum.each(companiesForIndustryEnrichment, &enrich_company_industry/1)
      {:ok, length(companiesForIndustryEnrichment)}
    end
  end

  defp enrich_company_industry(company) do
    OpenTelemetry.Tracer.with_span "company_enricher.enrich_industry" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      case CompanyEnrich.enrich_industry(company.id) do
        :ok ->
          Tracing.ok
          :ok

        {:error, reason} ->
          Tracing.error(inspect(reason))

          OpenTelemetry.Tracer.set_attributes([
            {"error.reason", inspect(reason)}
          ])

          {:error, reason}
      end
    end
  end

  defp fetch_companies_for_industry_enrichment(batch_size) do
    hours_ago_24 = DateTime.add(DateTime.utc_now(), -24 * 60 * 60)
    minutes_ago_10 = DateTime.add(DateTime.utc_now(), -10 * 60)
    max_attempts = 5

    Company
    |> where([c], is_nil(c.industry_code) or c.industry_code == "")
    |> where([c], not is_nil(c.homepage_content) and c.homepage_content != "")
    |> where([c], c.industry_enrichment_attempts < ^max_attempts)
    |> where(
      [c],
      is_nil(c.industry_enrich_attempt_at) or
        c.industry_enrich_attempt_at < ^hours_ago_24
    )
    |> where([c], c.inserted_at < ^minutes_ago_10)
    |> order_by([c], asc: c.industry_enrich_attempt_at)
    |> limit(^batch_size)
    |> Repo.all()
  end

  defp enrich_companies_name() do
    OpenTelemetry.Tracer.with_span "company_enricher.enrich_companies_name" do
      companiesForNameEnrichment =
        fetch_companies_for_name_enrichment(@default_batch_size)

      OpenTelemetry.Tracer.set_attributes([
        {"companies.found", length(companiesForNameEnrichment)},
        {"batch.size", @default_batch_size}
      ])

      # Enrich each company's name
      Enum.each(companiesForNameEnrichment, &enrich_company_name/1)
      {:ok, length(companiesForNameEnrichment)}
    end
  end

  defp enrich_company_name(company) do
    OpenTelemetry.Tracer.with_span "company_enricher.enrich_name" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      case CompanyEnrich.enrich_name(company.id) do
        :ok ->
          Tracing.ok
          :ok

        {:error, reason} ->
          Tracing.error(inspect(reason))

          {:error, reason}
      end
    end
  end

  defp fetch_companies_for_name_enrichment(batch_size) do
    hours_ago_24 = DateTime.add(DateTime.utc_now(), -24 * 60 * 60)
    minutes_ago_10 = DateTime.add(DateTime.utc_now(), -10 * 60)
    max_attempts = 5

    Company
    |> where([c], is_nil(c.name) or c.name == "")
    |> where([c], not is_nil(c.homepage_content) and c.homepage_content != "")
    |> where([c], c.name_enrichment_attempts < ^max_attempts)
    |> where(
         [c],
         is_nil(c.name_enrich_attempt_at) or
         c.name_enrich_attempt_at < ^hours_ago_24
       )
    |> where([c], c.inserted_at < ^minutes_ago_10)
    |> order_by([c], asc: c.name_enrich_attempt_at)
    |> limit(^batch_size)
    |> Repo.all()
  end

  defp enrich_companies_country() do
    OpenTelemetry.Tracer.with_span "company_enricher.enrich_companies_country" do
      companiesForCountryEnrichment =
        fetch_companies_for_country_enrichment(@default_batch_size)

      OpenTelemetry.Tracer.set_attributes([
        {"companies.found", length(companiesForCountryEnrichment)},
        {"batch.size", @default_batch_size}
      ])

      # Enrich each company's icon
      Enum.each(companiesForCountryEnrichment, &enrich_company_country/1)
      {:ok, length(companiesForCountryEnrichment)}
    end
  end

  defp enrich_company_country(company) do
    OpenTelemetry.Tracer.with_span "company_enricher.enrich_country" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      case CompanyEnrich.enrich_country(company.id) do
        :ok ->
          Tracing.ok
          :ok

        {:error, reason} ->
          Tracing.error(inspect(reason))

          {:error, reason}
      end
    end
  end

  defp fetch_companies_for_country_enrichment(batch_size) do
    hours_ago_24 = DateTime.add(DateTime.utc_now(), -24 * 60 * 60)
    minutes_ago_10 = DateTime.add(DateTime.utc_now(), -10 * 60)
    max_attempts = 5

    Company
    |> where([c], is_nil(c.country_a2) or c.country_a2 == "")
    |> where([c], not is_nil(c.homepage_content) and c.homepage_content != "")
    |> where([c], c.country_enrichment_attempts < ^max_attempts)
    |> where(
         [c],
         is_nil(c.country_enrich_attempt_at) or
         c.country_enrich_attempt_at < ^hours_ago_24
       )
    |> where([c], c.inserted_at < ^minutes_ago_10)
    |> order_by([c], asc: c.country_enrich_attempt_at)
    |> limit(^batch_size)
    |> Repo.all()
  end
end
