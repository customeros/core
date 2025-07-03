defmodule Core.Crm.TargetPersonas.TargetPersona do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}

  schema "target_personas" do
    field(:tenant_id, :string)
    field(:contact_id, :string)
    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t(),
          contact_id: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @required_fields [
    :tenant_id,
    :contact_id
  ]

  def changeset(%__MODULE__{} = persona, attrs) do
    persona
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> maybe_put_id()
  end

  defp maybe_put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Core.Utils.IdGenerator.generate_id_21("per"))
  end

  defp maybe_put_id(changeset), do: changeset
end
