defmodule Core.Repo.Migrations.AddLogoEnrichAttemptAtToCompanies do
  use Ecto.Migration

  def up do
    alter table(:companies) do
      add(:logo_enrich_attempt_at, :utc_datetime)
      remove(:icon_enrich_attempt_at)
    end
  end

  def down do
    alter table(:companies) do
      remove(:logo_enrich_attempt_at)
      add(:icon_enrich_attempt_at, :utc_datetime)
    end
  end
end
