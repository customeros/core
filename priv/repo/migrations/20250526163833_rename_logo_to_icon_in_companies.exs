defmodule Core.Repo.Migrations.RenameLogoToIconInCompanies do
  use Ecto.Migration

  def change do
    rename table(:companies), :logo_key, to: :icon_key
    rename table(:companies), :logo_enrich_attempt_at, to: :icon_enrich_attempt_at
    rename table(:companies), :logo_enrichment_attempts, to: :icon_enrichment_attempts
  end
end
