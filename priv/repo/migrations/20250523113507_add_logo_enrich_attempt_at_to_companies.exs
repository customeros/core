defmodule Core.Repo.Migrations.AddLogoEnrichAttemptAtToCompanies do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :logo_enrich_attempt_at, :utc_datetime
      remove :icon_enrich_attempt_at
    end
  end
end
