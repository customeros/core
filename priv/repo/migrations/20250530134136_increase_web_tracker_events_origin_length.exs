defmodule Core.Repo.Migrations.IncreaseWebTrackerEventsOriginLength do
  use Ecto.Migration

  def up do
    alter table(:web_tracker_events) do
      # Increase size of URL and user agent related fields
      modify(:origin, :string, size: 1024)
      modify(:referrer, :string, size: 1024)
      modify(:user_agent, :string, size: 1024)
      modify(:href, :string, size: 1024)
      modify(:search, :string, size: 1024)
      modify(:pathname, :string, size: 1024)
      # Hostnames are typically shorter
      modify(:hostname, :string, size: 255)
    end
  end

  def down do
    alter table(:web_tracker_events) do
      # Revert back to original sizes
      modify(:origin, :string, size: 255)
      modify(:referrer, :string, size: 255)
      modify(:user_agent, :string, size: 255)
      modify(:href, :string, size: 255)
      modify(:search, :string, size: 255)
      modify(:pathname, :string, size: 255)
      modify(:hostname, :string, size: 255)
    end
  end
end
