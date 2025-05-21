defmodule Core.WebTracker.Schemas.WebSession do
  @moduledoc """
  Schema definition for web sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  # Constants
  @id_prefix "sess"
  @id_regex ~r/^#{@id_prefix}_[a-z0-9]{21}$/

  schema "web_sessions" do
    field :tenant, :string
    field :visitor_id, :string
    field :origin, :string
    field :active, :boolean, default: true
    field :metadata, :map, default: %{}

    # IP information
    field :ip, :string
    field :city, :string
    field :region, :string
    field :country_code, :string
    field :is_mobile, :boolean

    # Custom timestamps
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :last_event_at, :utc_datetime
    field :last_event_type, :string

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
    id: String.t(),
    tenant: String.t(),
    visitor_id: String.t(),
    origin: String.t(),
    active: boolean(),
    metadata: map(),
    # IP information
    ip: String.t() | nil,
    city: String.t() | nil,
    region: String.t() | nil,
    country_code: String.t() | nil,
    is_mobile: boolean() | nil,
    # Timestamps
    started_at: DateTime.t() | nil,
    ended_at: DateTime.t() | nil,
    last_event_at: DateTime.t() | nil,
    last_event_type: String.t() | nil,
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @doc """
  Returns the ID prefix used for web sessions.
  """
  def id_prefix, do: @id_prefix

  @doc """
  Validates the changeset for a web session.
  """
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :id, :tenant, :visitor_id, :origin, :active, :metadata,
      :ip, :city, :region, :country_code, :is_mobile,
      :started_at, :ended_at, :last_event_at, :last_event_type
    ])
    |> validate_required([:id, :tenant, :visitor_id, :origin])
    |> validate_format(:id, @id_regex)
  end
end
