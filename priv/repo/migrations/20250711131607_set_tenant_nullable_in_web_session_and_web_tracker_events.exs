defmodule Core.Repo.Migrations.SetTenantNullableInWebSessionAndWebTrackerEvents do
  use Ecto.Migration

  def up do
    # Make tenant nullable in web_sessions table
    alter table(:web_sessions) do
      modify :tenant, :string, null: true
    end

    # Make tenant nullable in web_tracker_events table
    alter table(:web_tracker_events) do
      modify :tenant, :string, null: true
    end
  end

  def down do
    # Revert tenant to not null in web_sessions table
    alter table(:web_sessions) do
      modify :tenant, :string, null: false
    end

    # Revert tenant to not null in web_tracker_events table
    alter table(:web_tracker_events) do
      modify :tenant, :string, null: false
    end
  end
end
