defmodule Core.Crm.Companies.Enrich do
  use GenServer
  require Logger
  import Ecto.Query

  alias Core.Repo
  alias Core.Crm.Companies.Company
  alias Core.Researcher.Scraper
  alias Core.Crm.Industries
  alias Core.Utils.Media.Images
  alias Core.Crm.Companies.Enrichments

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

  @spec enrich_country(String.t()) :: :ok
  def enrich_country(company_id) when is_binary(company_id) do
    GenServer.cast(__MODULE__, {:enrich_country, company_id})
  end

  def enrich_country(_), do: {:error, :invalid_company_id}

  @spec enrich_icon(String.t()) :: :ok
  def enrich_icon(company_id) when is_binary(company_id) do
    GenServer.cast(__MODULE__, {:enrich_icon, company_id})
  end

  def enrich_icon(_), do: {:error, :invalid_company_id}

  @doc """
  Fetches companies that need icon enrichment.

  ## Parameters
    * `batch_size` - Number of records to return (default: 10)

  ## Returns
    * List of companies that:
      - Have no icon_key
      - Have not been attempted in the last 24 hours or have never been attempted
  """
  @spec fetch_companies_for_icon_enrichment(integer()) :: [Company.t()]
  def fetch_companies_for_icon_enrichment(batch_size \\ 10) do
    twenty_four_hours_ago = DateTime.add(DateTime.utc_now(), -24 * 60 * 60)
    ten_minutes_ago = DateTime.add(DateTime.utc_now(), -10 * 60)
    max_attempts = 5

    Company
    |> where([c], is_nil(c.icon_key) or c.icon_key == "")
    |> where([c], c.icon_enrichment_attempts < ^max_attempts)
    |> where(
      [c],
      is_nil(c.icon_enrich_attempt_at) or c.icon_enrich_attempt_at < ^twenty_four_hours_ago
    )
    |> where([c], c.inserted_at < ^ten_minutes_ago)
    |> order_by([c], asc: c.icon_enrich_attempt_at)
    |> limit(^batch_size)
    |> Repo.all()
  end

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

  @impl true
  def handle_cast({:enrich_country, company_id}, state) do
    Task.start(fn -> process_country_enrichment(company_id) end)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:enrich_icon, company_id}, state) do
    Task.start(fn -> process_icon_enrichment(company_id) end)
    {:noreply, state}
  end

  # Private Functions

  defp process_industry_enrichment(company_id) do
    case Repo.get(Company, company_id) do
      nil ->
        Logger.error("Company #{company_id} not found for industry enrichment")

      company ->
        if should_enrich_industry?(company) do
          {count, _} =
            Repo.update_all(
              from(c in Company, where: c.id == ^company_id),
              [
                set: [industry_enrich_attempt_at: DateTime.utc_now()],
                inc: [industry_enrichment_attempts: 1]
              ]
            )

          if count > 0 do
            # Get industry code from AI
            case Enrichments.Industry.identify(%{
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

                    if update_count == 0 do
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
          {count, _} =
            Repo.update_all(
              from(c in Company, where: c.id == ^company_id),
              [
                set: [name_enrich_attempt_at: DateTime.utc_now()],
                inc: [name_enrichment_attempts: 1]
              ]
            )

          if count > 0 do
            # Get company name from AI
            case Enrichments.Name.identify(%{
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

                if update_count == 0 do
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

  defp process_country_enrichment(company_id) do
    case Repo.get(Company, company_id) do
      nil ->
        Logger.warning("Company #{company_id} not found for country enrichment")

      company ->
        if should_enrich_country?(company) do
          {count, _} =
            Repo.update_all(
              from(c in Company, where: c.id == ^company_id),
              [
                set: [country_enrich_attempt_at: DateTime.utc_now()],
                inc: [country_enrichment_attempts: 1]
              ]
            )

          if count > 0 do
            # Get country code from AI
            case Enrichments.Location.identifyCountryCodeA2(%{
                   domain: company.primary_domain,
                   homepage_content: company.homepage_content
                 }) do
              {:ok, country_code_a2} ->
                # Ensure country code is uppercase before saving
                country_code_a2_uppercase = String.upcase(country_code_a2)

                # Update company with the identified country code
                {update_count, _} =
                  Repo.update_all(
                    from(c in Company, where: c.id == ^company_id),
                    set: [country_a2: country_code_a2_uppercase]
                  )

                if update_count == 0 do
                  Logger.error(
                    "Failed to update country for company #{company_id} (domain: #{company.primary_domain})"
                  )
                end

              {:error, reason} ->
                Logger.error(
                  "Failed to get country code from AI for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                )
            end
          else
            Logger.error(
              "Failed to mark country enrichment attempt for company #{company_id}"
            )
          end
        else
          Logger.info(
            "Skipping country enrichment for company #{company_id}: #{country_enrichment_skip_reason(company)}"
          )
        end
    end
  end

  defp process_icon_enrichment(company_id) do
    case Repo.get(Company, company_id) do
      nil ->
        Logger.error("Company #{company_id} not found for icon enrichment")

      company ->
        if should_enrich_icon?(company) do
          # Update both the attempt timestamp and increment attempts counter
          {count, _} =
            Repo.update_all(
              from(c in Company, where: c.id == ^company_id),
              [
                set: [icon_enrich_attempt_at: DateTime.utc_now()],
                inc: [icon_enrichment_attempts: 1]
              ]
            )

          if count > 0 do
            # Get Brandfetch client ID from configuration
            client_id =
              Application.get_env(:core, :brandfetch)[:client_id] ||
                raise "BRANDFETCH_CLIENT_ID is not configured"

            # Construct Brandfetch URL
            brandfetch_url =
              "https://cdn.brandfetch.io/#{company.primary_domain}/type/fallback/404/w/400/h/400?c=#{client_id}"

            # Download and store the icon
            case Images.download_image(brandfetch_url) do
              {:ok, image_data} ->
                # Only proceed with storage if we got actual image data
                case Images.store_image(image_data, "image/jpeg", brandfetch_url, %{
                       generate_name: true,
                       path: "_companies"
                     }) do
                  {:ok, storage_key} ->
                    # Update company with the icon storage key
                    {update_count, _} =
                      Repo.update_all(
                        from(c in Company, where: c.id == ^company_id),
                        set: [icon_key: storage_key]
                      )

                    if update_count == 0 do
                      Logger.error(
                        "Failed to update icon key for company #{company_id} (domain: #{company.primary_domain})"
                      )
                    end

                  {:error, reason} ->
                    Logger.error(
                      "Failed to store icon for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                    )
                end

              {:error, :image_not_found} ->
                {:error, :image_not_found}

              {:error, reason} ->
                Logger.error(
                  "Failed to download icon for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                )
                {:error, reason}
            end
          else
            Logger.error(
              "Failed to mark icon enrichment attempt for company #{company_id}"
            )
          end
        else
          Logger.error(
            "Skipping icon enrichment for company #{company_id}: #{icon_enrichment_skip_reason(company)}"
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

  defp should_enrich_country?(company) do
    cond do
      not is_nil(company.country_a2) and company.country_a2 != "" ->
        false

      is_nil(company.homepage_content) or company.homepage_content == "" ->
        false

      true ->
        true
    end
  end

  defp should_enrich_icon?(company) do
    cond do
      not is_nil(company.icon_key) and company.icon_key != "" ->
        false

      is_nil(company.primary_domain) or company.primary_domain == "" ->
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

  defp country_enrichment_skip_reason(company) do
    cond do
      not is_nil(company.country_a2) and company.country_a2 != "" ->
        "country_a2 already set"

      is_nil(company.homepage_content) or company.homepage_content == "" ->
        "no homepage content available"

      true ->
        "unknown"
    end
  end

  defp icon_enrichment_skip_reason(company) do
    cond do
      not is_nil(company.icon_key) and company.icon_key != "" ->
        "icon_key already set"

      is_nil(company.primary_domain) or company.primary_domain == "" ->
        "no primary domain available"

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
            # Start the scraping process
            Task.start(fn ->
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
                    enrich_industry(company_id)
                    enrich_name(company_id)
                    enrich_country(company_id)
                    enrich_icon(company_id)
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
