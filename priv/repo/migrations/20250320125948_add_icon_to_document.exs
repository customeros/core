defmodule Core.Repo.Migrations.AddIconToDocument do
  use Ecto.Migration

  def up do
    alter table(:documents) do
      add :icon, :string
    end
  end

  def down do
    alter table(:documents) do
      remove :icon
    end
  end
end
