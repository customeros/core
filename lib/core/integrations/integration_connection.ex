defmodule Core.Integrations.IntegrationConnection do
  @moduledoc """
  Schema module for managing integration connections.

  This schema represents a connection to an external integration (e.g., HubSpot)
  for a specific tenant. It stores OAuth credentials and connection status.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  # Constants
  @id_prefix "ic"
  @id_regex ~r/^#{@id_prefix}_[a-z0-9]{21}$/

  # Integration types
  @integration_types ["hubspot"]

  schema "integration_connections" do
    field :tenant_id, :string
    field :integration_type, :string
    field :status, :string
    field :credentials, :map
    field :settings, :map
    field :last_sync_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t(),
          integration_type: String.t(),
          status: String.t(),
          credentials: map(),
          settings: map() | nil,
          last_sync_at: DateTime.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  Returns the ID prefix used for integration connections.
  """
  def id_prefix, do: @id_prefix

  @doc """
  Returns list of valid integration types.
  """
  def integration_types, do: @integration_types

  @doc """
  Creates a changeset for integration connection.
  """
  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [
      :id,
      :tenant_id,
      :integration_type,
      :status,
      :credentials,
      :settings,
      :last_sync_at
    ])
    |> validate_required([:id, :tenant_id, :integration_type, :status, :credentials])
    |> validate_format(:id, @id_regex)
    |> validate_inclusion(:integration_type, @integration_types)
    |> validate_inclusion(:status, ["active", "inactive", "error"])
    |> unique_constraint([:tenant_id, :integration_type])
  end
end
