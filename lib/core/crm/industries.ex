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

  # Map of old NAICS codes to new ones
  @naics_code_map %{
    "333999" => "333998",
    "442110" => "449110",
    "448110" => "458110",
    "448120" => "458110",
    "453210" => "459410",
    "454110" => "444140",
    "485110" => "48511",
    "517110" => "517111",
    "519130" => "513120",
    "523110" => "523150",
    "523920" => "523940",
    "532290" => "532289"
  }

  @doc """
  Returns the new NAICS code if the given code is mapped; otherwise returns the code itself.
  """
  @spec map_naics_code(String.t()) :: String.t()
  def map_naics_code(code) when is_binary(code) do
    Map.get(@naics_code_map, code, code)
  end
end
