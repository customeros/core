defmodule Core.Repo.Migrations.AddScrapinEnrichmentColumns do
  use Ecto.Migration

  def up do
    alter table(:companies) do
      add(:scrapin_enrichment_attempts, :integer, default: 0, null: false)
      add(:scrapin_enrich_attempt_at, :utc_datetime)
    end
  end

  def down do
    alter table(:companies) do
      remove(:scrapin_enrichment_attempts)
      remove(:scrapin_enrich_attempt_at)
    end
  end
end
