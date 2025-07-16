defmodule Core.WebTracker.Sessions.Session do
  @moduledoc """
  Schema definition for web sessions.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Core.Enums.Channels
  alias Core.Enums.Platforms

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  # Constants
  @id_prefix "sess"
  @id_regex ~r/^#{@id_prefix}_[a-z0-9]{21}$/

  schema "web_sessions" do
    field(:tenant_id, :string)
    field(:visitor_id, :string)
    field(:origin, :string)
    field(:active, :boolean, default: true)
    field(:metadata, :map, default: %{})
    field(:just_created, :boolean, virtual: true, default: false)
    field(:company_id, :string)

    # IP information
    field(:ip, :string)
    field(:city, :string)
    field(:region, :string)
    field(:country_code, :string)
    field(:is_mobile, :boolean)

    # Attribution
    field(:channel, Ecto.Enum, values: Channels.channels())
    field(:platform, Ecto.Enum, values: Platforms.platforms())
    field(:referrer, :string)
    field(:utm_id, :string)
    field(:paid_id, :string)

    # Custom timestamps
    field(:started_at, :utc_datetime)
    field(:ended_at, :utc_datetime)
    field(:last_event_at, :utc_datetime)
    field(:last_event_type, :string)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t() | nil,
          visitor_id: String.t(),
          origin: String.t(),
          active: boolean(),
          metadata: map(),
          just_created: boolean(),
          company_id: String.t() | nil,
          # IP information
          ip: String.t() | nil,
          city: String.t() | nil,
          region: String.t() | nil,
          country_code: String.t() | nil,
          is_mobile: boolean() | nil,
          # Attribution
          channel: atom() | nil,
          platform: atom() | nil,
          referrer: String.t() | nil,
          utm_id: String.t() | nil,
          paid_id: String.t() | nil,
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
  def changeset(session \\ %__MODULE__{}, attrs) do
    session
    |> cast(attrs, [
      :id,
      :tenant_id,
      :visitor_id,
      :origin,
      :active,
      :metadata,
      :just_created,
      :company_id,
      :ip,
      :city,
      :region,
      :country_code,
      :is_mobile,
      :started_at,
      :ended_at,
      :last_event_at,
      :last_event_type,
      :channel,
      :platform,
      :referrer,
      :utm_id,
      :paid_id
    ])
    |> validate_required([:id, :visitor_id, :origin, :tenant_id])
    |> validate_format(:id, @id_regex)
  end
end
