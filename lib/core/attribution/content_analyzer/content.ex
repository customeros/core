defmodule Core.Attribution.ContentAnalyzer.Content do
  use Ecto.Schema
  import Ecto.Changeset

  alias Core.Utils.IdGenerator
  alias Core.Enums.ContentTypes

  @primary_key {:id, :string, autogenerate: false}

  @id_prefix "cont"

  schema "tenant_content" do
    field(:tenant_id, :string)
    field(:url, :string)
    field(:content_type, Ecto.Enum, values: ContentTypes.content_types())
    field(:primary_topic, :string)
    field(:key_pain_points, {:array, :string}, default: [])
    field(:product_attribution, :string)
    field(:journey_score, :integer)
    field(:expected_engagement_seconds, :integer)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t(),
          url: String.t() | nil,
          content_type: atom() | nil,
          product_attribution: String.t() | nil,
          primary_topic: String.t() | nil,
          key_pain_points: [String.t()] | nil,
          journey_score: Integer.t() | nil,
          expected_engagement_seconds: Integer.t() | nil
        }

  @required_fields [:tenant_id]
  @optional_fields [
    :url,
    :content_type,
    :product_attribution,
    :primary_topic,
    :key_pain_points,
    :journey_score,
    :expected_engagement_seconds
  ]

  def changeset(content \\ %__MODULE__{}, attrs) do
    content
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> maybe_put_id()
    |> validate_url()
    |> validate_journey_score()
    |> validate_expected_engagement()
  end

  def validate_journey_score(changeset) do
    changeset
    |> validate_number(:journey_score,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 10
    )
  end

  def validate_expected_engagement(changeset) do
    changeset
    |> validate_number(:expected_engagement_seconds,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 18_000
    )
  end

  defp validate_url(changeset) do
    changeset
    |> validate_format(:url, ~r/^https?:\/\//, message: "must be a valid URL")
    |> validate_length(:url, max: 2048)
  end

  defp maybe_put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, IdGenerator.generate_id_21(@id_prefix))
  end

  defp maybe_put_id(changeset), do: changeset
end
