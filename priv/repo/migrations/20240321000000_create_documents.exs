defmodule Core.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :body, :text, null: false
      add :tenant, :string, null: false
      add :user_id, :binary_id, null: false
      add :icon, :string
      add :color, :string
      add :organization_id, :binary_id, null: false

      timestamps()
    end

    create index(:documents, [:organization_id])
    create index(:documents, [:tenant])
    create index(:documents, [:user_id])
  end
end
