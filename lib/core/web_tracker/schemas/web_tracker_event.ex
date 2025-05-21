defmodule Core.WebTracker.Schemas.WebTrackerEvent do
  @moduledoc """
  Schema definition for web tracker events.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  # Constants
  @id_prefix "wevnt"
  @id_regex ~r/^#{@id_prefix}_[a-z0-9]{21}$/

  # Known event types
  @event_types [:page_view, :page_exit, :click, :identify]

  def event_types, do: @event_types

  schema "web_tracker_events" do
    # Required fields
    field :tenant, :string
    field :session_id, :string

    # Event information
    field :ip, :string
    field :visitor_id, :string
    field :event_type, :string
    field :event_data, :string
    field :timestamp, :utc_datetime
    field :href, :string
    field :origin, :string
    field :search, :string
    field :hostname, :string
    field :pathname, :string
    field :referrer, :string
    field :user_agent, :string
    field :language, :string
    field :cookies_enabled, :boolean
    field :screen_resolution, :string

    # Technical field
    field :created_at, :utc_datetime
  end

  @type event_type :: :page_view | :page_exit | :click | :identify

  @type t :: %__MODULE__{
    id: String.t(),
    tenant: String.t(),
    session_id: String.t(),
    ip: String.t() | nil,
    visitor_id: String.t() | nil,
    event_type: String.t() | nil,
    event_data: String.t() | nil,
    timestamp: DateTime.t() | nil,
    href: String.t() | nil,
    origin: String.t() | nil,
    search: String.t() | nil,
    hostname: String.t() | nil,
    pathname: String.t() | nil,
    referrer: String.t() | nil,
    user_agent: String.t() | nil,
    language: String.t() | nil,
    cookies_enabled: boolean() | nil,
    screen_resolution: String.t() | nil,
    created_at: DateTime.t()
  }

  @doc """
  Returns the ID prefix used for web tracker events.
  """
  def id_prefix, do: @id_prefix

  @doc """
  Validates the changeset for a web tracker event.
  """
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :id, :tenant, :session_id,
      :ip, :visitor_id, :event_type, :event_data, :timestamp,
      :href, :origin, :search, :hostname, :pathname,
      :referrer, :user_agent, :language,
      :cookies_enabled, :screen_resolution,
      :created_at
    ])
    |> validate_required([:id, :tenant, :session_id, :created_at])
    |> validate_format(:id, @id_regex)
  end
end
