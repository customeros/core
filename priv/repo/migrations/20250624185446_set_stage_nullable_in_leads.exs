defmodule Core.Repo.Migrations.SetStageNullableInLeads do
  use Ecto.Migration

  def up do
    alter table(:leads) do
      modify :stage, :lead_stage, null: true, default: "pending"
    end
  end

  def down do
    alter table(:leads) do
      modify :stage, :lead_stage, null: false, default: "pending"
    end
  end
end
