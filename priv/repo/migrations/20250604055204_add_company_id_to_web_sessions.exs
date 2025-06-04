defmodule Core.Repo.Migrations.AddCompanyIdToWebSessions do
  use Ecto.Migration

  def up do
    alter table(:web_sessions) do
      add :company_id, :string, null: true
    end

    create index(:web_sessions, [:company_id])
  end

  def down do
    drop index(:web_sessions, [:company_id])

    alter table(:web_sessions) do
      remove :company_id
    end
  end
end
