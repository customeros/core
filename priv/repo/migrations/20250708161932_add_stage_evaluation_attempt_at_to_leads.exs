defmodule Core.Repo.Migrations.AddStageEvaluationAttemptAtToLeads do
  use Ecto.Migration

  def up do
    alter table(:leads) do
      add :stage_evaluation_attempt_at, :utc_datetime
    end
  end

  def down do
    alter table(:leads) do
      remove :stage_evaluation_attempt_at
    end
  end
end
