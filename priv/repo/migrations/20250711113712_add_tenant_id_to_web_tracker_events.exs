defmodule Core.Repo.Migrations.AddTenantIdToWebTrackerEvents do
  use Ecto.Migration

  def up do
    alter table(:web_tracker_events) do
      add :tenant_id, :string, after: :tenant
    end

    create index(:web_tracker_events, [:tenant_id])
  end

  def down do
    alter table(:web_tracker_events) do
      remove :tenant_id
    end
  end
end
