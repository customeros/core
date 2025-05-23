defmodule Core.Repo.Migrations.CreateYjsDocumentWrites do
  use Ecto.Migration

  def up do
    create table(:document_writes) do
      add :docName, :string
      add :value, :binary
      add :version, :string

      timestamps(type: :utc_datetime)
    end

    create index(:document_writes, [:docName, :version])
  end

  def down do
    drop index(:document_writes, [:docName, :version])

    drop table(:document_writes)
  end
end
