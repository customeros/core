defmodule Core.Repo.Migrations.AddEnrichmentFieldsToCompanies do
  use Ecto.Migration

  def up do
    alter table(:companies) do
      # Enrichment attempt timestamps
      add :domain_scrape_attempt_at, :utc_datetime
      add :industry_enrich_attempt_at, :utc_datetime
      add :name_enrich_attempt_at, :utc_datetime
      add :icon_enrich_attempt_at, :utc_datetime

      # LinkedIn fields
      add :linkedin_id, :string
      add :linkedin_alias, :string
    end

    create index(:companies, [:linkedin_id])
    create index(:companies, [:linkedin_alias])
  end

  def down do
    drop index(:companies, [:linkedin_id])
    drop index(:companies, [:linkedin_alias])

    alter table(:companies) do
      remove :domain_scrape_attempt_at
      remove :industry_enrich_attempt_at
      remove :name_enrich_attempt_at
      remove :icon_enrich_attempt_at
      remove :linkedin_id
      remove :linkedin_alias
    end
  end
end
