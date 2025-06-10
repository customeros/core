defmodule Core.Repo.Migrations.AddDomainToLeads do
  use Ecto.Migration

  def up do
    alter table(:leads) do
      add(:domain, :string)
    end

    create(index(:leads, [:domain]))
  end

  def down do
    drop(index(:leads, [:domain]))

    alter table(:leads) do
      remove(:domain)
    end
  end
end
