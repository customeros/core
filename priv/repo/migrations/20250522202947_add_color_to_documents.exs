defmodule Core.Repo.Migrations.AddColorToDocuments do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add :color, :string, null: false, default: "#000000"
    end
  end
end
