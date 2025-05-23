defmodule Core.Repo.Migrations.AddCountryEnrichAttemptAtToCompanies do
  use Ecto.Migration

  def up do
    alter table(:companies) do
      add :country_enrich_attempt_at, :utc_datetime
    end
  end

  def down do
    alter table(:companies) do
      remove :country_enrich_attempt_at
    end
  end
end
