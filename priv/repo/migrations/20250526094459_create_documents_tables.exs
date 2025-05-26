defmodule Core.Repo.Migrations.CreateDocumentsTables do
  use Ecto.Migration

  def up do
    create table(:documents, primary_key: false) do
      add(:id, :string, primary_key: true, null: false)
      add(:name, :string)
      add(:body, :text)
      add(:lexical_state, :text)
      add(:tenant_id, :string)
      add(:user_id, :string)
      add(:icon, :string)
      add(:color, :string)

      timestamps(type: :utc_datetime)
    end

    create table(:refs_documents, primary_key: false) do
      add(:ref_id, :string, null: false)
      add(:document_id, :string, null: false)
    end

    create(index(:refs_documents, [:ref_id]))
    create(index(:refs_documents, [:ref_id, :document_id], unique: true))

    create table(:document_writes) do
      add(:document_id, :string, null: false)
      add(:value, :binary)
      add(:version, :string)

      timestamps(type: :utc_datetime)
    end

    create(index(:document_writes, [:document_id, :version]))
  end

  def down do
    drop(table(:document_writes))
    drop(table(:refs_documents))
    drop(table(:documents))
  end
end
