defmodule Core.Repo.Migrations.CreateTableLeadDomainQueues do
  use Ecto.Migration

  def up do
    create table(:lead_domain_queues) do
      add :tenant_id, :string, null: false
      add :domain, :string, null: false
      add :inserted_at, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
      add :rank, :integer, null: true
      add :processed_at, :utc_datetime, null: true
    end

    create unique_index(:lead_domain_queues, [:tenant_id, :domain],
             name: :lead_domain_queues_tenant_domain_unique_index
           )
  end

  def down do
    drop table(:lead_domain_queues)
  end
end
