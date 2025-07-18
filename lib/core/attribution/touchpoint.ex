defmodule Core.Attribution.Touchpoint do
  @moduledoc """
  Schema and changeset for tracking user interaction touchpoints in the attribution system.

  A touchpoint represents a significant interaction between a user and the system, capturing:
  - User and session identification
  - Lead and company association
  - Geographic location data
  - Channel and platform information
  - UTM and paid campaign tracking
  - Content interaction details
  - Stage transitions in the user journey
  - Engagement metrics (attention time)

  Touchpoints are crucial for understanding user behavior and attributing conversions
  to specific marketing channels and content.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Core.Enums.Channels
  alias Core.Enums.Platforms
  alias Core.Enums.LeadStages
  alias Core.Utils.IdGenerator
  alias Core.Enums.ContentTypes

  @primary_key {:id, :string, autogenerate: false}

  @id_prefix "touch"

  schema "touchpoints" do
    field(:tenant_id, :string)
    field(:session_id, :string)
    field(:lead_id, :string)
    field(:company_id, :string)
    field(:target_persona_id, :string)
    field(:contact_id, :string)
    field(:city, :string)
    field(:region, :string)
    field(:country_code, :string)
    field(:channel, Ecto.Enum, values: Channels.channels())
    field(:platform, Ecto.Enum, values: Platforms.platforms())
    field(:utm_id, :string)
    field(:paid_id, :string)
    field(:external_referrer, :string)
    field(:internal_referrer, :string)
    field(:content_url, :string)
    field(:content_type, Ecto.Enum, values: ContentTypes.content_types())
    field(:attention_seconds, :integer)
    field(:timestamp, :utc_datetime)
    field(:stage_start, Ecto.Enum, values: LeadStages.stages())
    field(:stage_end, Ecto.Enum, values: LeadStages.stages())
    field(:landing_page, :boolean, default: false)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t(),
          session_id: String.t() | nil,
          lead_id: String.t() | nil,
          company_id: String.t() | nil,
          target_persona_id: String.t() | nil,
          contact_id: String.t() | nil,
          city: String.t() | nil,
          region: String.t() | nil,
          country_code: String.t() | nil,
          channel: atom(),
          platform: atom() | nil,
          utm_id: String.t() | nil,
          paid_id: String.t() | nil,
          external_referrer: String.t() | nil,
          internal_referrer: String.t() | nil,
          content_url: String.t() | nil,
          content_type: atom(),
          attention_seconds: Integer.t(),
          timestamp: DateTime.t(),
          stage_start: atom(),
          stage_end: atom(),
          landing_page: Boolean.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @required_fields []
  @optional_fields []

  def changeset(touchpoint \\ %__MODULE__{}, attrs) do
    touchpoint
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> maybe_put_id()
  end

  defp maybe_put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, IdGenerator.generate_id_21(@id_prefix))
  end

  defp maybe_put_id(changeset), do: changeset
end
