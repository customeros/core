defmodule Core.Repo.Migrations.CreateIntegrationConnections do
  use Ecto.Migration

  def up do
    create table(:integration_connections, primary_key: false) do
      # Primary key and tenant
      add :id, :string, primary_key: true, size: 50
      add :tenant_id, :string, null: false, size: 50
      add :provider, :string, null: false, size: 50
      add :status, :string, null: false, default: "pending", size: 20
      add :external_system_id, :string, size: 50
      add :connection_error, :string

      # OAuth fields
      add :access_token, :string, null: false
      add :refresh_token, :string
      add :token_type, :string
      add :expires_at, :utc_datetime
      add :scopes, {:array, :string}

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create unique_index(:integration_connections, [:tenant_id, :provider])
    create index(:integration_connections, [:status])
    create index(:integration_connections, [:provider])
    create index(:integration_connections, [:expires_at])
    create index(:integration_connections, [:external_system_id])
  end

  def down do
    drop table(:integration_connections)
  end
end
