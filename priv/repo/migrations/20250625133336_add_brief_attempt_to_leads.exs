defmodule Core.Repo.Migrations.AddBriefAttemptToLeads do
  use Ecto.Migration

  def up do
    alter table(:leads) do
      add :brief_create_attempt_at, :utc_datetime
      add :brief_create_attempts, :integer, default: 0, null: false
    end

    # Create index for efficient querying of leads that need ICP fit evaluation
    create index(:leads, [:brief_create_attempts, :brief_create_attempt_at])
  end

  def down do
    # Drop index first
    drop index(:leads, [:brief_create_attempts, :brief_create_attempt_at])

    # Remove columns
    alter table(:leads) do
      remove :brief_create_attempt_at
      remove :brief_create_attempts
    end
  end
end
