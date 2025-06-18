defmodule Core.Repo.Migrations.CreateScrapinCompanies do
  use Ecto.Migration

  def up do
    create table(:scrapin_companies, primary_key: false) do
      add :id, :string, primary_key: true, null: false
      add :linkedin_id, :string
      add :linkedin_alias, :string
      add :domain, :string
      add :request_param, :string, null: false
      add :data, :text
      add :success, :boolean, default: false, null: false
      add :company_found, :boolean, default: false, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:scrapin_companies, [:linkedin_id])
    create index(:scrapin_companies, [:domain])
  end

  def down do
    drop table(:scrapin_companies)
  end
end
