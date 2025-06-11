defmodule Core.Repo.Migrations.CreateTableUserEvents do
  use Ecto.Migration

  def up do
    create table(:user_events) do
      add :user_id, :string, null: false
      add :event_type, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_events, [:user_id])
    create index(:user_events, [:event_type])
  end

  def down do
    drop table(:user_events)
  end
end
