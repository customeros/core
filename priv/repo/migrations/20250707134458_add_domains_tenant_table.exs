defmodule Core.Repo.Migrations.AddDomainsTenantTable do
  use Ecto.Migration

  def up do
    # Add the new columns
    alter table(:tenants) do
      add :primary_domain, :string
      add :domains, {:array, :string}, default: []
    end

    # Populate both new columns with the current domain value
    execute """
    UPDATE tenants 
    SET primary_domain = domain,
        domains = ARRAY[domain] 
    WHERE domain IS NOT NULL
    """

    # Make the new columns not null (after populating them)
    alter table(:tenants) do
      modify :primary_domain, :string, null: false
      modify :domains, {:array, :string}, null: false, default: []
    end

    # Remove the old domain column
    alter table(:tenants) do
      remove :domain
    end
  end

  def down do
    # Add back the domain column
    alter table(:tenants) do
      add :domain, :string
    end

    # Populate domain with primary_domain value
    execute """
    UPDATE tenants 
    SET domain = primary_domain 
    WHERE primary_domain IS NOT NULL
    """

    # Make domain not null (after populating it)
    alter table(:tenants) do
      modify :domain, :string, null: false
    end

    # Remove the new columns
    alter table(:tenants) do
      remove :primary_domain
      remove :domains
    end
  end
end
