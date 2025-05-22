defmodule Core.Repo.Migrations.AddCountryEnrichAttemptAtToCompanies do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :country_enrich_attempt_at, :utc_datetime
    end
  end
end
