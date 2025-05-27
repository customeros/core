defmodule Core.Auth.Tenants.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "tenants" do
    field(:name, :string)
    field(:domain, :string)
    field(:workspace_name, :string)
    field(:workspace_icon_key, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = tenant, attrs) do
    tenant
    |> cast(attrs, [:id, :name, :domain, :workspace_name, :workspace_icon_key])
    |> maybe_put_id()
    |> validate_required([:id, :name, :domain])
    |> validate_length(:name, max: 160)
    |> validate_length(:workspace_name, max: 160)
    |> unique_constraint(:name)
  end

  defp maybe_put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Core.Utils.IdGenerator.generate_id_16("tenant"))
  end

  defp maybe_put_id(changeset), do: changeset
end
