defmodule Core.Repo.Migrations.AddLastExecutionAtToCronLocking do
  use Ecto.Migration

  def up do
    alter table(:cron_locking) do
      add :last_execution_at, :utc_datetime
    end

    # Add index for faster queries on last_execution_at
    create index(:cron_locking, [:last_execution_at])
  end

  def down do
    # Remove index first
    drop index(:cron_locking, [:last_execution_at])

    alter table(:cron_locking) do
      remove :last_execution_at
    end
  end
end
