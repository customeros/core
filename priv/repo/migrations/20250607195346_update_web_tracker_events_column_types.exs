defmodule Core.Repo.Migrations.UpdateWebTrackerEventsColumnTypes do
  use Ecto.Migration

  def up do
    alter table(:web_tracker_events) do
      modify :referrer, :string, size: 4096
      modify :href, :string, size: 4096
      modify :user_agent, :string, size: 2048
      modify :search, :text
      modify :event_data, :text
      modify :origin, :string, size: 512
    end
  end

  def down do
    alter table(:web_tracker_events) do
      modify :referrer, :string, size: 2048
      modify :href, :string, size: 2048
      modify :user_agent, :string, size: 1024
      modify :search, :string, size: 2048
      modify :event_data, :string, size: 2048
      modify :origin, :string, size: 255
    end
  end
end
