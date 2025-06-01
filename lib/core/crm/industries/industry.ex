defmodule Core.Crm.Industries.Industry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:code, :string, autogenerate: false}
  @derive {Phoenix.Param, key: :code}
  schema "industries" do
    field(:name, :string)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
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
