defmodule Core.Repo.Migrations.DropDomainFromLeads do
  use Ecto.Migration

  def up do
    # Drop the index first
    drop index(:leads, [:domain])

    # Then remove the column
    alter table(:leads) do
      remove :domain
    end
  end

  def down do
    # Add the column back
    alter table(:leads) do
      add :domain, :string
    end

    # Recreate the index
    create index(:leads, [:domain])
  end
end
