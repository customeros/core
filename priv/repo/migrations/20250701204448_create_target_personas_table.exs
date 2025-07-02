defmodule Core.Repo.Migrations.CreateTargetPersonasTable do
  use Ecto.Migration

  def change do
    create table(:target_personas, primary_key: false) do
      add :id, :string, primary_key: true, null: false
      add :tenant_id, :string, null: false
      add :contact_id, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:target_personas, [:tenant_id])
    create index(:target_personas, [:contact_id])
    create unique_index(:target_personas, [:tenant_id, :contact_id])
  end
end
