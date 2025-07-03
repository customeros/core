defmodule Core.Repo.Migrations.CreateTableScrapinContacts do
  use Ecto.Migration

  def up do
    create table(:scrapin_contacts, primary_key: false) do
      add :id, :string, primary_key: true
      add :linkedin_id, :string
      add :linkedin_alias, :string
      add :request_param_linkedin, :string
      add :request_param_first_name, :string
      add :request_param_last_name, :string
      add :request_param_email, :string
      add :request_param_company_domain, :string
      add :request_param_company_name, :string
      add :data, :text
      add :success, :boolean, default: false, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:scrapin_contacts, [:linkedin_id])
  end

  def down do
    drop table(:scrapin_contacts)
  end
end
