defmodule Core.Repo.Migrations.CreateContactsTable do
  use Ecto.Migration

  def change do
    create table(:contacts, primary_key: false) do
      add :id, :string, primary_key: true, null: false
      add :first_name, :string
      add :last_name, :string
      add :full_name, :string
      add :linkedin_id, :string
      add :linkedin_alias, :string
      add :business_email, :string
      add :business_email_status, :string
      add :personal_email, :string
      add :personal_email_status, :string
      add :mobile_phone, :string
      add :city, :string
      add :region, :string
      add :country_a2, :string, size: 2
      add :avatar_key, :string
      add :current_job_title, :string
      add :current_company_id, :string
      add :seniority, :string
      add :department, :string

      timestamps(type: :utc_datetime)
    end

    # Indexes for common queries
    create index(:contacts, [:linkedin_id])
    create index(:contacts, [:business_email])
    create index(:contacts, [:personal_email])
    create index(:contacts, [:current_company_id])
    create index(:contacts, [:full_name])
    create index(:contacts, [:country_a2])
    create index(:contacts, [:seniority])
    create index(:contacts, [:department])

    # Unique constraints
    create unique_index(:contacts, [:linkedin_id], where: "linkedin_id IS NOT NULL")
    create unique_index(:contacts, [:business_email], where: "business_email IS NOT NULL")
  end
end
