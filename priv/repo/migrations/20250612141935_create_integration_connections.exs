defmodule Core.Repo.Migrations.CreateIntegrationConnections do
  use Ecto.Migration

  def up do
    create table(:integration_connections, primary_key: false) do
      add :id, :string, primary_key: true, size: 50
      add :tenant_id, :string, null: false, size: 50
      add :integration_type, :string, null: false, size: 50
      add :status, :string, null: false, size: 20
      add :credentials, :map, null: false
      add :settings, :map
      add :last_sync_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create unique_index(:integration_connections, [:tenant_id, :integration_type])
    create index(:integration_connections, [:status])
    create index(:integration_connections, [:integration_type])
  end

  def down do
    drop table(:integration_connections)
  end
end
