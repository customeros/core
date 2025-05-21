defmodule Core.Repo.Migrations.AddLastEventTypeToWebSessions do
  use Ecto.Migration

  def change do
    alter table(:web_sessions) do
      add :last_event_type, :string
    end

    create index(:web_sessions, [:last_event_type])
  end
end
