defmodule Core.Repo.Migrations.AddAnalyticsJobsTable do
  use Ecto.Migration

  def change do
    create_query = "CREATE TYPE job_status AS ENUM ('pending', 'completed', 'failed')"
    drop_query = "DROP TYPE job_status"
    execute(create_query, drop_query)

    create table(:analytics_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :job_type, :string, null: false
      add :tenant_id, :string, null: false
      add :scheduled_at, :utc_datetime, null: false
      add :status, :job_status, null: false, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create index(:analytics_jobs, [:tenant_id])
    create index(:analytics_jobs, [:status])
    create index(:analytics_jobs, [:scheduled_at])
    create index(:analytics_jobs, [:job_type, :status])
  end
end
