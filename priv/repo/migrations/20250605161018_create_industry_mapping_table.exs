defmodule Core.Repo.Migrations.CreateIndustryMappingTable do
  use Ecto.Migration

  def up do
    create table(:industry_mappings) do
      add :code_source, :string, null: false
      add :code_target, :string, null: false
      add :inserted_at, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
    end

    create index(:industry_mappings, [:code_source])
  end

  def down do
    drop table(:industry_mappings)
  end
end
