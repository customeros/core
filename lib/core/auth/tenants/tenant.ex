defmodule Core.Auth.Tenants.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "tenants" do
    field(:name, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = tenant, attrs) do
    tenant
    |> cast(attrs, [:id, :name])
    |> maybe_put_id()
    |> validate_required([:id, :name])
    |> validate_length(:name, max: 160)
    |> unique_constraint(:name)
  end

  defp maybe_put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Core.Utils.IdGenerator.generate_id_21("tenant"))
  end

  defp maybe_put_id(changeset), do: changeset
end
