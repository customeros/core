defmodule Core.Repo.Migrations.CreateExternalCompanies do
  use Ecto.Migration

  def up do
    create table(:external_companies, primary_key: false) do
      add :id, :string, primary_key: true, size: 50
      add :integration_connection_id, references(:integration_connections, type: :string, on_delete: :delete_all), null: false
      add :external_id, :string, null: false, size: 255
      add :company_id, :string, null: false, size: 50
      add :external_data, :map
      add :last_synced_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create unique_index(:external_companies, [:integration_connection_id, :external_id])
    create index(:external_companies, [:company_id])
    create index(:external_companies, [:integration_connection_id])
    create index(:external_companies, [:last_synced_at])
  end

  def down do
    drop table(:external_companies)
  end
end
