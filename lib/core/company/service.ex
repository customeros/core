defmodule Core.Company.Service do
  alias Core.Company.Companies
  alias Core.Company.Schemas.Company
  alias Core.Utils.PrimaryDomain
  alias Core.Company.Enrich

  @spec get_or_create_by_domain(any()) ::
          {:ok, Company.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def get_or_create_by_domain(domain) when not is_binary(domain),
    do: {:error, "domain must be a string"}

  def get_or_create_by_domain(domain) when is_binary(domain) do
    case Companies.get_by_primary_domain(domain) do
      nil ->
        # Company doesn't exist, validate domain and create it
        case PrimaryDomain.primary_domain_check(domain) do
          {true, primary_domain} ->
            create_company_and_trigger_scraping(primary_domain)

          {false, primary_domain} when primary_domain != "" ->
            create_company_and_trigger_scraping(primary_domain)

          {false, ""} ->
            {:error, "not a valid domain"}
        end

      company ->
        # Company exists, return it
        {:ok, company}
    end
  end

  defp create_company_and_trigger_scraping(primary_domain) when is_binary(primary_domain) do
    with {:ok, company} <- Companies.create_with_domain(primary_domain) do
      Enrich.scrape_homepage(company.id)
      {:ok, company}
    end
  end
end
