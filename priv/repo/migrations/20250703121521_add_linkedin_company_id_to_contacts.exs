defmodule Core.Repo.Migrations.AddLinkedinCompanyIdToContacts do
  use Ecto.Migration

  def up do
    alter table(:contacts) do
      add :linkedin_company_id, :string
    end

    # Add index for common queries
    create index(:contacts, [:linkedin_company_id])
  end

  def down do
    # Remove index first
    drop index(:contacts, [:linkedin_company_id])

    # Remove column
    alter table(:contacts) do
      remove :linkedin_company_id
    end
  end
end
