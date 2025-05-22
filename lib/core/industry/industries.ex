defmodule Core.Industry.Industries do
  alias Core.Repo
  alias Core.Industry.Schemas.Industry

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
