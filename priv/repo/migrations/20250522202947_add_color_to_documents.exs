defmodule Core.Repo.Migrations.AddColorToDocuments do
  use Ecto.Migration

  def up do
    alter table(:documents) do
      add :color, :string, null: false, default: "#000000"
    end
  end

  def down do
    alter table(:documents) do
      remove :color
    end
  end
end
