defmodule Core.Crm.Industries do
  @moduledoc """
  Context module for managing industries in the CRM system.

  Provides functions for retrieving and creating industry records.
  Industries are used to categorize and organize CRM entities.
  """

  alias Core.Crm.Industries.IndustryMapping
  alias Core.Repo
  alias Core.Crm.Industries.Industry

  @spec get_by_code(String.t()) :: Industry.t() | nil
  def get_by_code(code) when is_binary(code) do
    code
    |> map_naics_code()
    |> (&Repo.get_by(Industry, code: &1)).()
  end

  def get_by_code(_), do: nil

  @spec create(map()) :: {:ok, Industry.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Industry{}
    |> Industry.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns the new NAICS code if the given code is mapped; otherwise returns the code itself.
  """
  @spec map_naics_code(String.t()) :: String.t()
  def map_naics_code(code) when is_binary(code) do
    case get_mapped_industry_code(code) do
      {:ok, mapped_code} -> mapped_code
      {:error, :not_found} -> code
    end
  end

  @spec get_mapped_industry_code(String.t()) ::
          {:ok, String.t()} | {:error, :not_found}
  def get_mapped_industry_code(industry_code) do
    case Repo.get_by(IndustryMapping, code_source: industry_code) do
      nil ->
        {:error, :not_found}

      mapping ->
        {:ok, mapping.code_target}
    end
  end
end
