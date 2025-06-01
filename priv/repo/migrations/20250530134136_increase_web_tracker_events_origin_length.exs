defmodule Core.Repo.Migrations.IncreaseWebTrackerEventsOriginLength do
  use Ecto.Migration

  def change do
    alter table(:web_tracker_events) do
      # Increase size of URL and user agent related fields
      modify :origin, :string, size: 1024
      modify :referrer, :string, size: 1024
      modify :user_agent, :string, size: 1024
      modify :href, :string, size: 1024
      modify :search, :string, size: 1024
      modify :pathname, :string, size: 1024
      # Hostnames are typically shorter
      modify :hostname, :string, size: 255
    end
  end
end
