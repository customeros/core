defmodule Core.Repo.Migrations.AddStageTimestampAndTryAttemptsToLeads do
  use Ecto.Migration

  def up do
    alter table(:leads) do
      add :icp_fit_attempt_at, :utc_datetime
      add :icp_fit_attempts, :integer, default: 0, null: false
    end

    # Create index for efficient querying of leads that need ICP fit evaluation
    create index(:leads, [:icp_fit_attempts, :icp_fit_attempt_at])
  end

  def down do
    # Drop index first
    drop index(:leads, [:icp_fit_attempts, :icp_fit_attempt_at])

    # Remove columns
    alter table(:leads) do
      remove :icp_fit_attempt_at
      remove :icp_fit_attempts
    end
  end
end
