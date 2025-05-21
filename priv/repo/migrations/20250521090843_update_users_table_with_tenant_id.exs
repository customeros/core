defmodule Core.Repo.Migrations.UpdateUsersTableWithTenantId do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :tenant_id, references(:tenants, type: :string, on_delete: :delete_all), null: false
    end
  end
end
