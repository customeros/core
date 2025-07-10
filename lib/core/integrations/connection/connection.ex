defmodule Core.Integrations.Connection do
  @moduledoc """
  Schema for integration connections.

  This schema represents a connection to an external integration provider (e.g., HubSpot)
  for a specific tenant. It stores OAuth credentials and connection status.

  ## Fields
  - `id` - Unique identifier for the connection (16 characters)
  - `tenant_id` - ID of the tenant this connection belongs to
  - `provider` - The integration provider (:hubspot)
  - `status` - Current status of the connection (:pending, :active, :inactive, :error, :refreshing, :disconnected)
  - `external_system_id` - HubSpot portal ID or other provider's unique ID
  - `connection_error` - Error message if connection failed

  ## OAuth Fields
  - `access_token` - OAuth access token
  - `refresh_token` - OAuth refresh token
  - `token_type` - Type of token (e.g., "Bearer")
  - `expires_at` - When the access token expires
  - `scopes` - List of granted OAuth scopes
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type provider :: :hubspot | :google_ads
  @type status ::
          :pending | :active | :inactive | :error | :refreshing | :disconnected
  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t(),
          provider: provider(),
          status: status(),
          external_system_id: String.t() | nil,
          access_token: String.t(),
          refresh_token: String.t() | nil,
          token_type: String.t(),
          expires_at: DateTime.t(),
          scopes: [String.t()] | nil,
          connection_error: String.t() | nil,
          company_sync_after: String.t() | nil,
          company_sync_completed: boolean(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string
  schema "integration_connections" do
    # Primary fields
    field(:tenant_id, :string)
    field(:provider, Ecto.Enum, values: [:hubspot, :google_ads])

    field(:status, Ecto.Enum,
      values: [:pending, :active, :inactive, :error, :refreshing, :disconnected],
      default: :pending
    )

    field(:external_system_id, :string)

    # OAuth fields
    field(:access_token, :string)
    field(:refresh_token, :string)
    field(:token_type, :string)
    field(:expires_at, :utc_datetime)
    field(:scopes, {:array, :string})
    field(:connection_error, :string)

    field(:company_sync_after, :string)
    field(:company_sync_completed, :boolean)

    timestamps(type: :utc_datetime)
  end

  @id_regex ~r/^icn_[a-zA-Z0-9]{16}$/

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
      :external_system_id,
      :access_token,
      :refresh_token,
      :token_type,
      :expires_at,
      :scopes,
      :connection_error,
      :company_sync_after,
      :company_sync_completed
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
