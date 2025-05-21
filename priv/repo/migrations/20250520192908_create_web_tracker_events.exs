defmodule Core.Repo.Migrations.CreateWebTrackerEvents do
  use Ecto.Migration

  def change do
    create table(:web_tracker_events, primary_key: false) do
      # Primary fields
      add :id, :string, primary_key: true
      add :tenant, :string, null: false
      add :session_id, :string, null: false

      # Event information
      add :ip, :string
      add :visitor_id, :string
      add :event_type, :string
      add :event_data, :text  # Using text for potentially large JSON data
      add :timestamp, :utc_datetime
      add :href, :string
      add :origin, :string
      add :search, :string
      add :hostname, :string
      add :pathname, :string
      add :referrer, :string
      add :user_agent, :string
      add :language, :string
      add :cookies_enabled, :boolean
      add :screen_resolution, :string

      timestamps(type: :utc_datetime)
    end

    # Create indexes for common queries
    create index(:web_tracker_events, [:tenant])
    create index(:web_tracker_events, [:session_id])
    create index(:web_tracker_events, [:visitor_id])
    create index(:web_tracker_events, [:timestamp])
  end
end
