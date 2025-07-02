defmodule Core.Repo.Migrations.AddTrafficToWebSessions do
  use Ecto.Migration

  def up do
    alter table(:web_sessions) do
      add :traffic_source, :string
      add :traffic_type, :string
    end

    # Add indexes for better query performance
    create index(:web_sessions, [:traffic_source])
    create index(:web_sessions, [:traffic_type])
    create index(:web_sessions, [:traffic_source, :traffic_type])
  end

  def down do
    alter table(:web_sessions) do
      remove :traffic_source
      remove :traffic_type
    end
  end
end
