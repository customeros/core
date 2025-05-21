defmodule Core.Company.Service do
  @moduledoc """
  Service module for company-related business logic.
  """

  alias Core.Company.Companies
  alias Core.Company.Schemas.Company

  @doc """
  Creates a company by domain if it doesn't exist, otherwise returns the existing one.
  """
  @spec create_by_domain(any()) :: {:ok, Company.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def create_by_domain(domain) when not is_binary(domain),
    do: {:error, "domain must be a string"}
  def create_by_domain(domain) when is_binary(domain) do
    case Companies.get_by_domain(domain) do
      nil ->
        # Company doesn't exist, create it
        Companies.create_with_domain(domain)

      company ->
        # Company exists, return it
        {:ok, company}
    end
  end
end
