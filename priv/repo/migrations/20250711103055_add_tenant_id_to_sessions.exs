defmodule Core.Repo.Migrations.AddTenantIdToSessions do
  use Ecto.Migration

  def up do
    alter table(:web_sessions) do
      add :tenant_id, :string, after: :tenant
    end

    create index(:web_sessions, [:tenant_id])
  end

  def down do
    alter table(:web_sessions) do
      remove :tenant_id
    end
  end
end
