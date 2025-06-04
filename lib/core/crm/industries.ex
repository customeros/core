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
    "115110" => "11511",
    "211111" => "211120",
    "236110" => "23611",
    "323110" => "323111",
    "333999" => "333998",
    "335911" => "335910",
    "441228" => "441227",
    "442110" => "449110",
    "443142" => "449210",
    "444210" => "444230",
    "448110" => "458110",
    "448120" => "458110",
    "448210" => "458210",
    "451110" => "459110",
    "453210" => "459410",
    "454110" => "444140",
    "454310" => "457210",
    "485110" => "48511",
    "513990" => "519290",
    "517110" => "517111",
    "517311" => "517111",
    "517919" => "517810",
    "519130" => "513120",
    "523110" => "523150",
    "523120" => "523150",
    "523140" => "523130",
    "523920" => "523940",
    "523930" => "523940",
    "532290" => "532289",
    "811213" => "811210",
    "812110" => "81211",
    "999990" => "999999"
  }

  @doc """
  Returns the new NAICS code if the given code is mapped; otherwise returns the code itself.
  """
  @spec map_naics_code(String.t()) :: String.t()
  def map_naics_code(code) when is_binary(code) do
    Map.get(@naics_code_map, code, code)
  end
end
