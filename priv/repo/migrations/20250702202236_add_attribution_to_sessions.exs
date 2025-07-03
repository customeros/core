defmodule Core.Repo.Migrations.AddAttributionToSessions do
  use Ecto.Migration

  def change do
    alter table(:web_sessions) do
      add :channel, :string
      add :search_platform, :string
      add :social_platform, :string
      add :utm_id, :string
      add :paid_id, :string
    end

    create index(:web_sessions, [:channel])
    create index(:web_sessions, [:utm_id])
    create index(:web_sessions, [:paid_id])
  end

  def down do
    alter table(:web_sessions) do
      remove :channel
      remove :search_platform
      remove :social_platform
      remove :utm_id
      remove :paid_id
    end
  end
end
