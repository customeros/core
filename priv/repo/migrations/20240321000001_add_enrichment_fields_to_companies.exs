defmodule Core.Repo.Migrations.AddEnrichmentFieldsToCompanies do
  use Ecto.Migration

  def change do
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

    # Create index for LinkedIn ID lookups
    create index(:companies, [:linkedin_id])
    create index(:companies, [:linkedin_alias])
  end
end
