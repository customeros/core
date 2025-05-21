defmodule Core.Repo.Migrations.AddLastEventAtToWebSessions do
  use Ecto.Migration

  def change do
    alter table(:web_sessions) do
      add :last_event_at, :utc_datetime, null: false
    end

    # Create an index for last_event_at for better query performance
    create index(:web_sessions, [:last_event_at])
  end
end
