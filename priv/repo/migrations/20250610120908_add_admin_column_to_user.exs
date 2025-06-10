defmodule Core.Repo.Migrations.AddAdminColumnToUser do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add(:admin, :boolean, default: false)
    end

    create(index(:users, [:admin]))
  end

  def down do
    drop(index(:users, [:admin]))

    alter table(:users) do
      remove(:admin)
    end
  end
end
