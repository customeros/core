defmodule Core.Research.Webpages.ScrapedWebpage do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          url: String.t(),
          domain: String.t(),
          content: String.t(),
          links: [String.t()],
          # Classification fields
          primary_topic: String.t() | nil,
          secondary_topics: [String.t()],
          solution_focus: [String.t()],
          content_type: String.t() | nil,
          industry_vertical: String.t() | nil,
          key_pain_points: [String.t()],
          value_proposition: String.t() | nil,
          referenced_customers: [String.t()],
          # Intent scores
          problem_recognition_score: integer() | nil,
          solution_research_score: integer() | nil,
          evaluation_score: integer() | nil,
          purchase_readiness_score: integer() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "scraped_webpages" do
    field(:url, :string)
    field(:domain, :string)
    field(:content, :string)
    field(:links, {:array, :string}, default: [])

    # Classification fields
    field(:primary_topic, :string)
    field(:secondary_topics, {:array, :string}, default: [])
    field(:solution_focus, {:array, :string}, default: [])
    field(:content_type, :string)
    field(:industry_vertical, :string)
    field(:key_pain_points, {:array, :string}, default: [])
    field(:value_proposition, :string)
    field(:referenced_customers, {:array, :string}, default: [])

    # Intent scores
    field(:problem_recognition_score, :integer)
    field(:solution_research_score, :integer)
    field(:evaluation_score, :integer)
    field(:purchase_readiness_score, :integer)

    timestamps()
  end

  @required_fields [:url, :domain, :content]
  @optional_fields [
    :links,
    :primary_topic,
    :secondary_topics,
    :solution_focus,
    :content_type,
    :industry_vertical,
    :key_pain_points,
    :value_proposition,
    :referenced_customers,
    :problem_recognition_score,
    :solution_research_score,
    :evaluation_score,
    :purchase_readiness_score
  ]

  def changeset(scraped_webpage, attrs) do
    scraped_webpage
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_intent_scores()
    |> unique_constraint(:url)
  end

  # Removed the strict URL validation since you're passing domain names
  defp validate_intent_scores(changeset) do
    changeset
    |> validate_number(:problem_recognition_score,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 5
    )
    |> validate_number(:solution_research_score,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 5
    )
    |> validate_number(:evaluation_score,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 5
    )
    |> validate_number(:purchase_readiness_score,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 5
    )
  end
end
