defmodule Core.Crm.Companies.Enrich do
  use GenServer
  require Logger
  import Ecto.Query

  alias Core.Repo
  alias Core.Crm.Companies.Company
  alias Core.Scraper.Scrape
  alias Core.Crm.Industries

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec scrape_homepage(String.t()) :: :ok
  def scrape_homepage(company_id) when is_binary(company_id) do
    GenServer.cast(__MODULE__, {:scrape_homepage, company_id})
  end

  def scrape_homepage(_), do: {:error, :invalid_company_id}

  @spec enrich_industry(String.t()) :: :ok
  def enrich_industry(company_id) when is_binary(company_id) do
    GenServer.cast(__MODULE__, {:enrich_industry, company_id})
  end

  def enrich_industry(_), do: {:error, :invalid_company_id}

  @spec enrich_name(String.t()) :: :ok
  def enrich_name(company_id) when is_binary(company_id) do
    GenServer.cast(__MODULE__, {:enrich_name, company_id})
  end

  def enrich_name(_), do: {:error, :invalid_company_id}

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

  @impl true
  def handle_cast({:enrich_industry, company_id}, state) do
    Task.start(fn -> process_industry_enrichment(company_id) end)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:enrich_name, company_id}, state) do
    Task.start(fn -> process_name_enrichment(company_id) end)
    {:noreply, state}
  end

  # Private Functions

  defp process_industry_enrichment(company_id) do
    case Repo.get(Company, company_id) do
      nil ->
        Logger.warning(
          "Company #{company_id} not found for industry enrichment"
        )

      company ->
        if should_enrich_industry?(company) do
          # Safely update only the industry_enrich_attempt_at field
          {count, _} =
            Repo.update_all(
              from(c in Company, where: c.id == ^company_id),
              set: [industry_enrich_attempt_at: DateTime.utc_now()]
            )

          if count > 0 do
            Logger.debug(
              "Starting industry enrichment for company #{company_id} (domain: #{company.primary_domain})"
            )

            # Get industry code from AI
            case Core.AI.Company.Industry.identify(%{
                   domain: company.primary_domain,
                   homepage_content: company.homepage_content
                 }) do
              {:ok, industry_code} ->
                # Get industry name from our industries table
                case Industries.get_by_code(industry_code) do
                  nil ->
                    Logger.warning(
                      "Industry code #{industry_code} not found in industries table for company #{company_id}"
                    )

                  industry ->
                    # Update company with industry code and name
                    {update_count, _} =
                      Repo.update_all(
                        from(c in Company, where: c.id == ^company_id),
                        set: [
                          industry_code: industry.code,
                          industry: industry.name
                        ]
                      )

                    if update_count > 0 do
                      Logger.info(
                        "Successfully enriched industry for company #{company_id} (domain: #{company.primary_domain}): #{industry.code} - #{industry.name}"
                      )
                    else
                      Logger.error(
                        "Failed to update industry for company #{company_id} (domain: #{company.primary_domain})"
                      )
                    end
                end

              {:error, reason} ->
                Logger.error(
                  "Failed to get industry code from AI for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                )
            end
          else
            Logger.error(
              "Failed to mark industry enrichment attempt for company #{company_id}"
            )
          end
        else
          Logger.info(
            "Skipping industry enrichment for company #{company_id}: #{enrichment_skip_reason(company)}"
          )
        end
    end
  end

  defp process_name_enrichment(company_id) do
    case Repo.get(Company, company_id) do
      nil ->
        Logger.warning("Company #{company_id} not found for name enrichment")

      company ->
        if should_enrich_name?(company) do
          # Safely update only the name_enrich_attempt_at field
          {count, _} =
            Repo.update_all(
              from(c in Company, where: c.id == ^company_id),
              set: [name_enrich_attempt_at: DateTime.utc_now()]
            )

          if count > 0 do
            Logger.debug(
              "Starting name enrichment for company #{company_id} (domain: #{company.primary_domain})"
            )

            # Get company name from AI
            case Core.AI.Company.Name.identify(%{
                   domain: company.primary_domain,
                   homepage_content: company.homepage_content
                 }) do
              {:ok, name} ->
                # Update company with the identified name
                {update_count, _} =
                  Repo.update_all(
                    from(c in Company, where: c.id == ^company_id),
                    set: [name: name]
                  )

                if update_count > 0 do
                  Logger.info(
                    "Successfully enriched name for company #{company_id} (domain: #{company.primary_domain}): #{name}"
                  )
                else
                  Logger.error(
                    "Failed to update name for company #{company_id} (domain: #{company.primary_domain})"
                  )
                end

              {:error, reason} ->
                Logger.error(
                  "Failed to get company name from AI for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                )
            end
          else
            Logger.error(
              "Failed to mark name enrichment attempt for company #{company_id}"
            )
          end
        else
          Logger.info(
            "Skipping name enrichment for company #{company_id}: #{name_enrichment_skip_reason(company)}"
          )
        end
    end
  end

  defp should_enrich_industry?(company) do
    cond do
      not is_nil(company.industry_code) ->
        false

      is_nil(company.homepage_content) or company.homepage_content == "" ->
        false

      true ->
        true
    end
  end

  defp should_enrich_name?(company) do
    cond do
      not is_nil(company.name) and company.name != "" ->
        false

      is_nil(company.homepage_content) or company.homepage_content == "" ->
        false

      true ->
        true
    end
  end

  defp enrichment_skip_reason(company) do
    cond do
      not is_nil(company.industry_code) ->
        "industry_code already set"

      is_nil(company.homepage_content) or company.homepage_content == "" ->
        "no homepage content available"

      true ->
        "unknown"
    end
  end

  defp name_enrichment_skip_reason(company) do
    cond do
      not is_nil(company.name) and company.name != "" ->
        "name already set"

      is_nil(company.homepage_content) or company.homepage_content == "" ->
        "no homepage content available"

      true ->
        "unknown"
    end
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
            Logger.debug(
              "Starting homepage scraping for company #{company_id} (domain: #{company.primary_domain})"
            )

            # Start the scraping process
            Task.start(fn ->
              case Scrape.scrape_webpage(company.primary_domain) do
                {:ok, result} ->
                  {update_count, _} =
                    Repo.update_all(
                      from(c in Company, where: c.id == ^company_id),
                      set: [homepage_content: result.content]
                    )

                  if update_count > 0 do
                    Logger.info(
                      "Successfully scraped and stored homepage content for company #{company_id} (domain: #{company.primary_domain})"
                    )

                    # Trigger enrichment processes after successful scraping
                    enrich_industry(company_id)
                    enrich_name(company_id)
                  else
                    Logger.error(
                      "Failed to store scraped content for company #{company_id} (domain: #{company.primary_domain})"
                    )
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
