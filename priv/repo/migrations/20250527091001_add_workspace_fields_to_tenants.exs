defmodule Core.Repo.Migrations.AddWorkspaceFieldsToTenants do
  use Ecto.Migration

  def change do
    alter table(:tenants) do
      add :workspace_name, :string
      add :workspace_icon_key, :string
    end
  end
end
