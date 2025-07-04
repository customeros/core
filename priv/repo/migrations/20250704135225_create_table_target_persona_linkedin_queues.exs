defmodule Core.Repo.Migrations.CreateTableContactLinkedinQueues do
  use Ecto.Migration

  def up do
    create table(:target_persona_linkedin_queues) do
      add :tenant_id, :string, null: false
      add :linkedin_url, :string, null: false
      add :inserted_at, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
      add :completed_at, :utc_datetime, null: true
      add :last_attempt_at, :utc_datetime, null: true
      add :attempts, :integer, null: false, default: 0
    end

    create unique_index(:target_persona_linkedin_queues, [:tenant_id, :linkedin_url],
             name: :target_persona_linkedin_queues_tenant_linkedin_url_unique_index
           )
  end

  def down do
    drop table(:target_persona_linkedin_queues)
  end
end
