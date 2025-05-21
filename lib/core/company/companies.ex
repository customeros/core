defmodule Core.Company.Companies do
  import Ecto.Query
  alias Core.Repo
  alias Core.Utils.IdGenerator
  alias Core.Company.Schemas.Company

  @spec create_with_domain(any()) :: {:ok, Company.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def create_with_domain(domain) when not is_binary(domain),
    do: {:error, "domain must be a string"}
  def create_with_domain(domain) when is_binary(domain) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Company{primary_domain: domain}
    |> Map.put(:id, IdGenerator.generate_id_21(Company.id_prefix()))
    |> Map.put(:created_at, now)
    |> Map.put(:updated_at, now)
    |> Company.changeset(%{})
    |> Repo.insert()
  end

  @spec get_by_domain(any()) :: Company.t() | nil
  def get_by_domain(domain) when not is_binary(domain), do: nil
  def get_by_domain(domain) when is_binary(domain) do
    Repo.get_by(Company, primary_domain: domain)
  end
end
