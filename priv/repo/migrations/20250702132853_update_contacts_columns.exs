defmodule Core.Repo.Migrations.UpdateContactsColumns do
  use Ecto.Migration

  def up do
    # Rename existing columns
    rename table(:contacts), :current_job_title, to: :job_title
    rename table(:contacts), :current_company_id, to: :company_id

    # Add new columns
    alter table(:contacts) do
      add :company_domain, :string
      add :description, :string
      add :job_started_at, :utc_datetime
      add :job_ended_at, :utc_datetime
    end
  end

  def down do
    # Remove new columns
    alter table(:contacts) do
      remove :company_domain
      remove :description
      remove :job_started_at
      remove :job_ended_at
    end

    # Rename columns back to original names
    rename table(:contacts), :job_title, to: :current_job_title
    rename table(:contacts), :company_id, to: :current_company_id
  end
end
