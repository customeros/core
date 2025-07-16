defmodule Core.Repo.Migrations.AddEnrichFieldsToContact do
  use Ecto.Migration

  def up do
    alter table(:contacts) do
      add :enrich_attempts, :integer, default: 0, null: false
      add :enrich_attempt_at, :utc_datetime_usec
      add :timezone, :string
    end
  end

  def down do
    alter table(:contacts) do
      remove :enrich_attempts
      remove :enrich_attempt_at
      remove :timezone
    end
  end
end
