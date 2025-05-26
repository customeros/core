defmodule Core.Repo.Migrations.AddEnrichmentAttemptsToCompanies do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :logo_enrichment_attempts, :integer, default: 0, null: false
      add :industry_enrichment_attempts, :integer, default: 0, null: false
      add :name_enrichment_attempts, :integer, default: 0, null: false
      add :country_enrichment_attempts, :integer, default: 0, null: false
    end

    # Create indexes for efficient querying of companies that need enrichment
    create index(:companies, [:logo_enrichment_attempts, :logo_enrich_attempt_at])
    create index(:companies, [:industry_enrichment_attempts, :industry_enrich_attempt_at])
    create index(:companies, [:name_enrichment_attempts, :name_enrich_attempt_at])
    create index(:companies, [:country_enrichment_attempts, :country_enrich_attempt_at])
  end
end
