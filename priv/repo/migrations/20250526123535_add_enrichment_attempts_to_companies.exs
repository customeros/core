defmodule Core.Repo.Migrations.AddEnrichmentAttemptsToCompanies do
  use Ecto.Migration

  def up do
    alter table(:companies) do
      add(:logo_enrichment_attempts, :integer, default: 0, null: false)
      add(:industry_enrichment_attempts, :integer, default: 0, null: false)
      add(:name_enrichment_attempts, :integer, default: 0, null: false)
      add(:country_enrichment_attempts, :integer, default: 0, null: false)
    end

    # Create indexes for efficient querying of companies that need enrichment
    create(index(:companies, [:logo_enrichment_attempts, :logo_enrich_attempt_at]))

    create(
      index(:companies, [
        :industry_enrichment_attempts,
        :industry_enrich_attempt_at
      ])
    )

    create(index(:companies, [:name_enrichment_attempts, :name_enrich_attempt_at]))

    create(
      index(:companies, [
        :country_enrichment_attempts,
        :country_enrich_attempt_at
      ])
    )
  end

  def down do
    # Drop indexes first
    drop(index(:companies, [:logo_enrichment_attempts, :logo_enrich_attempt_at]))

    drop(
      index(:companies, [
        :industry_enrichment_attempts,
        :industry_enrich_attempt_at
      ])
    )

    drop(index(:companies, [:name_enrichment_attempts, :name_enrich_attempt_at]))

    drop(
      index(:companies, [
        :country_enrichment_attempts,
        :country_enrich_attempt_at
      ])
    )

    # Remove columns
    alter table(:companies) do
      remove(:logo_enrichment_attempts)
      remove(:industry_enrichment_attempts)
      remove(:name_enrichment_attempts)
      remove(:country_enrichment_attempts)
    end
  end
end
