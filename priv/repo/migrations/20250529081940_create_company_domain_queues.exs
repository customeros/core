defmodule Core.Repo.Migrations.CreateCompanyDomainQueues do
  use Ecto.Migration

  def up do
    create table(:company_domain_queues) do
      add :domain, :string, null: false
      add :processed_at, :utc_datetime
      add :inserted_at, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
    end

    # Add index on domain for faster lookups
    create index(:company_domain_queues, [:domain])
    # Add index on processed_at for faster querying of unprocessed records
    create index(:company_domain_queues, [:processed_at])
  end

  def down do
    drop table(:company_domain_queues)
  end
end
