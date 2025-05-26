defmodule Core.Repo.Migrations.AddOrganizationIdToDocuments do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add :organization_id, :binary_id, null: false
    end
    create index(:documents, [:organization_id])
  end
end
