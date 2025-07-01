defmodule Core.Repo.Migrations.CreateBetterContactJobsTable do
  use Ecto.Migration

  def change do
    create table(:better_contact_jobs) do
      add :job_id, :string, null: false
      add :contact_id, :string
      add :status, :string, default: "processing"
      add :completed_attempts, :integer, default: 0
      add :next_check_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:better_contact_jobs, [:job_id])
    create index(:better_contact_jobs, [:status])
    create index(:better_contact_jobs, [:next_check_at])
    create index(:better_contact_jobs, [:contact_id])
  end
end
