defmodule Core.Industry.Schemas.Industry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "industries" do
    field :code, :string
    field :name, :string

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
    id: integer(),
    code: String.t(),
    name: String.t(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  def changeset(industry, attrs) do
    industry
    |> cast(attrs, [:code, :name])
    |> validate_required([:code, :name])
    |> unique_constraint(:code)
  end
end
