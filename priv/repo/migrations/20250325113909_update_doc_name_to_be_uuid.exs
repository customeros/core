defmodule Core.Repo.Migrations.UpdateDocNameToBeUuid do
  use Ecto.Migration

  def up do
    drop index(:document_writes, [:docName, :version])

    alter table(:document_writes) do
      remove :docName
    end

    alter table(:document_writes) do
      add :docName, references(:documents, type: :uuid, on_delete: :delete_all), null: false
    end

    create index(:document_writes, [:docName, :version])
  end

  def down do
    alter table(:document_writes) do
      remove :docName
    end

    alter table(:document_writes) do
      add :docName, :string, null: false
    end

    create index(:document_writes, [:docName, :version])
  end
end
