defmodule Core.Repo.Migrations.RemoveTenantFromWebSessions do
  use Ecto.Migration

  def up do
    alter table(:web_sessions) do
      remove :tenant
    end
  end

  def down do
    alter table(:web_sessions) do
      add :tenant, :string
    end
  end
end
