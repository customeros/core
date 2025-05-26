defmodule Core.Crm.Companies do
  alias Core.Repo
  alias Core.Crm.Companies.Company
  alias Core.Crm.Companies.Enrich
  alias Core.Utils.IdGenerator
  alias Core.Utils.PrimaryDomainFinder

  @spec get_or_create_by_domain(any()) ::
          {:ok, Company.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def get_or_create_by_domain(domain) when not is_binary(domain),
    do: {:error, "domain must be a string"}

  def get_or_create_by_domain(domain) when is_binary(domain) do
    case PrimaryDomainFinder.get_primary_domain(domain) do
      {:ok, primary_domain} when primary_domain != "" ->
        case get_by_primary_domain(primary_domain) do
          nil ->
            # Company doesn't exist, create it
            create_company_and_trigger_scraping(primary_domain)

          company ->
            # Company exists, return it
            {:ok, company}
        end

      _ ->
        {:error, "not a valid domain"}
    end
  end

  defp create_company_and_trigger_scraping(primary_domain) when is_binary(primary_domain) do
    with {:ok, company} <- create_with_domain(primary_domain) do
      Enrich.scrape_homepage(company.id)
      {:ok, company}
    end
  end

  @spec create_with_domain(any()) ::
          {:ok, Company.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def create_with_domain(domain) when not is_binary(domain),
    do: {:error, "domain must be a string"}

  def create_with_domain(domain) when is_binary(domain) do
    %Company{primary_domain: domain}
    |> Map.put(:id, IdGenerator.generate_id_21(Company.id_prefix()))
    |> Company.changeset(%{})
    |> Repo.insert()
  end

  @spec get_by_primary_domain(any()) :: Company.t() | nil
  def get_by_primary_domain(domain) when not is_binary(domain), do: nil

  def get_by_primary_domain(domain) when is_binary(domain) do
    Repo.get_by(Company, primary_domain: domain)
  end
end
