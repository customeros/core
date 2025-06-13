defmodule Core.Integrations.IntegrationConnection do
  @moduledoc """
  Schema for integration connections.

  This schema represents a connection to an external integration provider (e.g., HubSpot)
  for a specific tenant. It stores OAuth credentials and connection status.

  ## Fields
  - `id` - Unique identifier for the connection (16 characters)
  - `tenant_id` - ID of the tenant this connection belongs to
  - `provider` - The integration provider (:hubspot)
  - `status` - Current status of the connection (:pending, :active, :inactive, :error, :refreshing, :disconnected)

  ## OAuth Fields
  - `access_token` - OAuth access token
  - `refresh_token` - OAuth refresh token
  - `token_type` - Type of token (e.g., "Bearer")
  - `expires_at` - When the access token expires
  - `scopes` - List of granted OAuth scopes

  ## Sync Tracking
  - `last_sync_at` - When the last sync completed
  - `last_sync_status` - Status of the last sync
  - `last_sync_error` - Error message if last sync failed
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type provider :: :hubspot
  @type status :: :pending | :active | :inactive | :error | :refreshing | :disconnected
  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t(),
          provider: provider(),
          status: status(),
          access_token: String.t(),
          refresh_token: String.t() | nil,
          token_type: String.t(),
          expires_at: DateTime.t(),
          scopes: [String.t()] | nil,
          last_sync_at: DateTime.t() | nil,
          last_sync_status: String.t() | nil,
          last_sync_error: String.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string
  schema "integration_connections" do
    # Primary fields
    field :tenant_id, :string
    field :provider, Ecto.Enum, values: [:hubspot]
    field :status, Ecto.Enum,
      values: [:pending, :active, :inactive, :error, :refreshing, :disconnected],
      default: :pending

    # OAuth fields
    field :access_token, :string
    field :refresh_token, :string
    field :token_type, :string
    field :expires_at, :utc_datetime
    field :scopes, {:array, :string}

    # Sync tracking
    field :last_sync_at, :utc_datetime
    field :last_sync_status, :string
    field :last_sync_error, :string

    timestamps(type: :utc_datetime)
  end

  @id_regex ~r/^icn_[a-zA-Z0-9]{12}$/

  @doc """
  Creates a changeset for the integration connection.
  """
  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [
      :id,
      :tenant_id,
      :provider,
      :status,
      :access_token,
      :refresh_token,
      :token_type,
      :expires_at,
      :scopes,
      :last_sync_at,
      :last_sync_status,
      :last_sync_error
    ])
    |> validate_required([
      :id,
      :tenant_id,
      :provider,
      :status,
      :access_token,
      :token_type,
      :expires_at
    ])
    |> validate_format(:id, @id_regex)
    |> unique_constraint([:tenant_id, :provider])
  end

  @doc """
  Returns the prefix used for generating IDs.
  """
  def id_prefix, do: "icn"
end
