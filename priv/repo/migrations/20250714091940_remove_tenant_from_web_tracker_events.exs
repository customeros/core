defmodule Core.Repo.Migrations.RemoveTenantFromWebTrackerEvents do
  use Ecto.Migration

  def up do
    alter table(:web_tracker_events) do
      remove :tenant
    end
  end

  def down do
    alter table(:web_tracker_events) do
      add :tenant, :string
    end
  end
end
