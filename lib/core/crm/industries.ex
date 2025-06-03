defmodule Core.Crm.Industries do
  @moduledoc """
  Context module for managing industries in the CRM system.

  Provides functions for retrieving and creating industry records.
  Industries are used to categorize and organize CRM entities.
  """

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
  Map of old (2017 and before) NAICS codes to new (2022) NAICS codes.
  """
  @naics_code_map %{
    "454110" => "444140",
    "453210" => "459410"
  }

  @doc """
  Returns the new NAICS code if the given code is mapped; otherwise returns the code itself.
  """
  @spec map_naics_code(String.t()) :: String.t()
  def map_naics_code(code) when is_binary(code) do
    Map.get(@naics_code_map, code, code)
  end
end
