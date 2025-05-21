defmodule Core.Repo.Migrations.CreateWebSessions do
  use Ecto.Migration

  def change do
    create table(:web_sessions, primary_key: false) do
      # Primary fields
      add :id, :string, primary_key: true
      add :tenant, :string, null: false
      add :visitor_id, :string, null: false
      add :origin, :string, null: false
      add :active, :boolean, default: true
      add :metadata, :map, default: %{}

      # IP information
      add :ip, :string
      add :city, :string
      add :region, :string
      add :country_code, :string
      add :is_mobile, :boolean

      # Timestamps
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime, null: true
      add :last_event_at, :utc_datetime
      add :last_event_type, :string

      timestamps(type: :utc_datetime)
    end

    # Create indexes for common queries
    create index(:web_sessions, [:tenant])
    create index(:web_sessions, [:visitor_id])
    create index(:web_sessions, [:tenant, :visitor_id, :origin, :active])
    create index(:web_sessions, [:ip])
  end
end
