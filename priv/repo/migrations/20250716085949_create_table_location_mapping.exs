defmodule Core.Repo.Migrations.CreateTableLocationMapping do
  use Ecto.Migration

  def up do
    create table(:location_mapping) do
      add :location, :string, null: false
      add :country_a2, :string
      add :region, :string
      add :city, :string
      add :timezone, :string

      timestamps()
    end

    create index(:location_mapping, [:location])
  end

  def down do
    drop table(:location_mapping)
  end
end
