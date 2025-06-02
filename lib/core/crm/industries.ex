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
    Repo.get_by(Industry, code: code)
  end

  def get_by_code(_), do: nil

  @spec create(map()) :: {:ok, Industry.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Industry{}
    |> Industry.changeset(attrs)
    |> Repo.insert()
  end
end
