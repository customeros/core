defmodule Core.Repo.Migrations.CreateTableCronLocking do
  use Ecto.Migration

  def up do
    create table(:cron_locking) do
      add :cron_name, :string, null: false
      add :lock, :string
      add :locked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Add unique index on cron_name
    create unique_index(:cron_locking, [:cron_name])
  end

  def down do
    drop table(:cron_locking)
  end
end
