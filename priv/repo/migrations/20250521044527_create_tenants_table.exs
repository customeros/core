defmodule Core.Repo.Migrations.CreateTenantsTable do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :citext, null: false
      add :domain, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:tenants, [:name])
  end
end
