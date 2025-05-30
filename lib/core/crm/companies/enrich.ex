defmodule Core.Crm.Companies.Enrich do
  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query

  alias Core.Repo
  alias Core.Crm.Companies.Company
  alias Core.Researcher.Scraper
  alias Core.Crm.Companies.CompanyEnrich

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec scrape_homepage(String.t()) :: :ok
  def scrape_homepage(company_id) when is_binary(company_id) do
    GenServer.cast(__MODULE__, {:scrape_homepage, company_id})
  end

  def scrape_homepage(_), do: {:error, :invalid_company_id}

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:scrape_homepage, company_id}, state) do
    Task.start(fn -> process_homepage_scraping(company_id) end)
    {:noreply, state}
  end

  defp process_homepage_scraping(company_id) do
    case Repo.get(Company, company_id) do
      nil ->
        Logger.warning("Company #{company_id} not found for homepage scraping")

      company ->
        if should_scrape_homepage?(company) do
          # Mark the attempt first
          {count, _} =
            Repo.update_all(
              from(c in Company, where: c.id == ^company_id),
              set: [domain_scrape_attempt_at: DateTime.utc_now()]
            )

          if count > 0 do
            span_ctx = OpenTelemetry.Tracer.current_span_ctx()
            # Start the scraping process
            Task.start(fn ->
              OpenTelemetry.Tracer.set_current_span(span_ctx)
              case Scraper.scrape_webpage(company.primary_domain) do
                {:ok, result} ->
                  {update_count, _} =
                    Repo.update_all(
                      from(c in Company, where: c.id == ^company_id),
                      set: [homepage_content: result.content]
                    )

                  if update_count == 0 do
                    Logger.error(
                      "Failed to store scraped content for company #{company_id} (domain: #{company.primary_domain})"
                    )
                  else
                    # Trigger enrichment processes after successful scraping
                    CompanyEnrich.enrich_industry_task(company_id)
                    CompanyEnrich.enrich_name_task(company_id)
                    CompanyEnrich.enrich_country_task(company_id)
                    CompanyEnrich.enrich_icon_task(company_id)
                  end

                {:error, reason} ->
                  Logger.error(
                    "Failed to scrape homepage for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                  )
              end
            end)
          else
            Logger.error(
              "Failed to mark scraping attempt for company #{company_id} (domain: #{company.primary_domain})"
            )
          end
        else
          Logger.info(
            "Skipping homepage scraping for company #{company_id} (domain: #{company.primary_domain}): #{homepage_scraping_skip_reason(company)}"
          )
        end
    end
  end

  defp should_scrape_homepage?(company) do
    cond do
      not is_nil(company.homepage_content) and company.homepage_content != "" ->
        false

      is_nil(company.primary_domain) or company.primary_domain == "" ->
        false

      true ->
        true
    end
  end

  defp homepage_scraping_skip_reason(company) do
    cond do
      not is_nil(company.homepage_content) and company.homepage_content != "" ->
        "homepage content already exists"

      is_nil(company.primary_domain) or company.primary_domain == "" ->
        "no primary domain available"

      true ->
        "unknown"
    end
  end
end
