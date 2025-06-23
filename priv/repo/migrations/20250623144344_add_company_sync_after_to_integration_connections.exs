defmodule Core.Repo.Migrations.AddCompanySyncAfterToIntegrationConnections do
  use Ecto.Migration

  def up do
    alter table(:integration_connections) do
      add :company_sync_after, :string
      add :company_sync_completed, :boolean, default: false, null: false
    end
  end

  def down do
    alter table(:integration_connections) do
      remove :company_sync_after
      remove :company_sync_completed
    end
  end
end
