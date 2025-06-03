defmodule Core.Crm.Companies.CompanyEnricher do
  @moduledoc """
  GenServer responsible for periodically enriching company data.
  Runs every 2 or 15 minutes (based on found records) and processes companies that need enrichment for various fields:
  - Icon
  - Industry
  - Name
  - Country
  - Homepage
  """
  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query

  alias Core.Repo
  alias Core.Crm.Companies.Company
  alias Core.Crm.Companies.CompanyEnrich
  alias Core.Utils.Tracing

  # 2 minutes
  @default_interval_ms 2 * 60 * 1000
  # 15 minutes
  @long_interval_ms 15 * 60 * 1000
  @default_batch_size 5

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
      {_, num_companies_for_icon_enrichment} = enrich_companies_icon()
      {_, num_companies_for_industry_enrichment} = enrich_companies_industry()
      {_, num_companies_for_name_enrichment} = enrich_companies_name()
      {_, num_companies_for_country_enrichment} = enrich_companies_country()

      {_, num_companies_for_homepage_scrape} =
        enrich_companies_homepage_scrape()

      # Schedule the next check - use default interval if either enrichment hit the batch size
      next_interval_ms =
        if num_companies_for_icon_enrichment == @default_batch_size or
             num_companies_for_name_enrichment == @default_batch_size or
             num_companies_for_country_enrichment == @default_batch_size or
             num_companies_for_industry_enrichment == @default_batch_size or
             num_companies_for_homepage_scrape == @default_batch_size do
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
      companies_for_icon_enrichment =
        fetch_companies_for_icon_enrichment(@default_batch_size)

      OpenTelemetry.Tracer.set_attributes([
        {"companies.found", length(companies_for_icon_enrichment)},
        {"batch.size", @default_batch_size}
      ])

      # Enrich each company's icon
      Enum.each(companies_for_icon_enrichment, &enrich_company_icon/1)
      {:ok, length(companies_for_icon_enrichment)}
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
          Tracing.ok()
          :ok

        {:error, :image_not_found} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", :image_not_found}
          ])

          {:error, :image_not_found}

        {:error, reason} ->
          Tracing.error(reason)

          Logger.error(
            "Error enriching icon for company #{company.id} (domain: #{company.primary_domain}): #{inspect(reason)}"
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
      companies_for_industry_enrichment =
        fetch_companies_for_industry_enrichment(@default_batch_size)

      OpenTelemetry.Tracer.set_attributes([
        {"companies.found", length(companies_for_industry_enrichment)},
        {"batch.size", @default_batch_size}
      ])

      # Enrich each company's icon
      Enum.each(companies_for_industry_enrichment, &enrich_company_industry/1)
      {:ok, length(companies_for_industry_enrichment)}
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
          Tracing.ok()
          :ok

        {:error, :industry_not_found} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", :industry_not_found}
          ])

          {:error, :industry_not_found}

        {:error, reason} ->
          Tracing.error(reason)

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
      companies_for_name_enrichment =
        fetch_companies_for_name_enrichment(@default_batch_size)

      OpenTelemetry.Tracer.set_attributes([
        {"companies.found", length(companies_for_name_enrichment)},
        {"batch.size", @default_batch_size}
      ])

      # Enrich each company's name
      Enum.each(companies_for_name_enrichment, &enrich_company_name/1)
      {:ok, length(companies_for_name_enrichment)}
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
          Tracing.ok()
          :ok

        {:error, reason} ->
          Tracing.error(reason)

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
      companies_for_country_enrichment =
        fetch_companies_for_country_enrichment(@default_batch_size)

      OpenTelemetry.Tracer.set_attributes([
        {"companies.found", length(companies_for_country_enrichment)},
        {"batch.size", @default_batch_size}
      ])

      # Enrich each company's icon
      Enum.each(companies_for_country_enrichment, &enrich_company_country/1)
      {:ok, length(companies_for_country_enrichment)}
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
          Tracing.ok()
          :ok

        {:error, reason} ->
          Tracing.error(reason)

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

  defp enrich_companies_homepage_scrape() do
    OpenTelemetry.Tracer.with_span "company_enricher.enrich_companies_homepage_scrape" do
      companies_for_homepage_scrape =
        fetch_companies_for_homepage_scrape(@default_batch_size)

      OpenTelemetry.Tracer.set_attributes([
        {"companies.found", length(companies_for_homepage_scrape)},
        {"batch.size", @default_batch_size}
      ])

      # Enrich each company's icon
      Enum.each(
        companies_for_homepage_scrape,
        &enrich_company_homepage_scrape/1
      )

      {:ok, length(companies_for_homepage_scrape)}
    end
  end

  defp enrich_company_homepage_scrape(company) do
    OpenTelemetry.Tracer.with_span "company_enricher.enrich_company_homepage_scrape" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      case CompanyEnrich.scrape_homepage(company.id) do
        :ok ->
          Tracing.ok()
          :ok

        {:error, reason} ->
          Tracing.error(reason)

          {:error, reason}
      end
    end
  end

  defp fetch_companies_for_homepage_scrape(batch_size) do
    hours_ago_24 = DateTime.add(DateTime.utc_now(), -24 * 60 * 60)
    minutes_ago_30 = DateTime.add(DateTime.utc_now(), -30 * 60)
    max_attempts = 5

    Company
    |> where([c], is_nil(c.homepage_content) or c.homepage_content == "")
    |> where([c], c.domain_scrape_attempts < ^max_attempts)
    |> where(
      [c],
      is_nil(c.domain_scrape_attempt_at) or
        c.domain_scrape_attempt_at < ^hours_ago_24
    )
    |> where([c], c.inserted_at < ^minutes_ago_30)
    |> order_by([c], asc: c.domain_scrape_attempt_at)
    |> limit(^batch_size)
    |> Repo.all()
  end
end
