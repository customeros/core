defmodule Core.Repo.Migrations.AddLinkedinIdsAndDomainsToCompanies do
  use Ecto.Migration

  def up do
    alter table(:companies) do
      add :linkedin_ids, {:array, :string}, default: []
      add :domains, {:array, :string}, default: []
      remove :linkedin_alias
    end

    create index(:companies, [:domains], using: :gin)
    create index(:companies, [:linkedin_ids], using: :gin)
  end

  def down do
    drop index(:companies, [:domains])
    drop index(:companies, [:linkedin_ids])

    alter table(:companies) do
      remove :linkedin_ids
      remove :domains
      add :linkedin_alias, :string
    end
  end
end
