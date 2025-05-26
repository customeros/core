defmodule Core.Repo.Migrations.CreateScrapedWebpages do
  use Ecto.Migration

  def change do
    create table(:scraped_webpages) do
      # Basic webpage data
      add :url, :string, null: false
      add :domain, :string, null: false
      add :content, :text, null: false
      add :links, {:array, :text}, default: []

      # Classification fields
      add :primary_topic, :string
      add :secondary_topics, {:array, :string}, default: []
      add :solution_focus, {:array, :string}, default: []
      add :content_type, :string
      add :industry_vertical, :string
      add :key_pain_points, {:array, :string}, default: []
      add :value_proposition, :text
      add :referenced_customers, {:array, :string}, default: []

      # Profile intent scores (1-5 range)
      add :problem_recognition_score, :integer
      add :solution_research_score, :integer
      add :evaluation_score, :integer
      add :purchase_readiness_score, :integer

      timestamps()
    end

    # Indexes
    create unique_index(:scraped_webpages, [:url])
    create index(:scraped_webpages, [:domain])
    create index(:scraped_webpages, [:content_type])
    create index(:scraped_webpages, [:industry_vertical])
    create index(:scraped_webpages, [:primary_topic])

    # Add constraints for intent scores (1-5 range)
    create constraint(:scraped_webpages, :problem_recognition_score_range,
             check: "problem_recognition_score >= 1 AND problem_recognition_score <= 5"
           )

    create constraint(:scraped_webpages, :solution_research_score_range,
             check: "solution_research_score >= 1 AND solution_research_score <= 5"
           )

    create constraint(:scraped_webpages, :evaluation_score_range,
             check: "evaluation_score >= 1 AND evaluation_score <= 5"
           )

    create constraint(:scraped_webpages, :purchase_readiness_score_range,
             check: "purchase_readiness_score >= 1 AND purchase_readiness_score <= 5"
           )
  end
end
