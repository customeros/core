defmodule Core.Auth.Tenants.Tenant do
  @moduledoc """
  Schema module representing a tenant in the authentication system.

  A tenant represents a workspace or organization in the system, with properties
  including name, domain, and workspace details. Each tenant has a unique ID
  and is used to segregate data and users across different organizations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :domain,
             :workspace_name,
             :workspace_icon_key,
             :webtracker_status,
             :inserted_at,
             :updated_at
           ]}
  @primary_key {:id, :string, autogenerate: false}
  schema "tenants" do
    field(:name, :string)
    field(:domain, :string)
    field(:workspace_name, :string)
    field(:workspace_icon_key, :string)
    field(:webtracker_status, Ecto.Enum, values: [:available, :not_available])

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          domain: String.t(),
          workspace_name: String.t(),
          workspace_icon_key: String.t(),
          webtracker_status: Ecto.Enum.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  def changeset(%__MODULE__{} = tenant, attrs) do
    tenant
    |> cast(attrs, [
      :id,
      :name,
      :domain,
      :workspace_name,
      :workspace_icon_key,
      :webtracker_status
    ])
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
