defmodule Core.Repo.Migrations.AddDisqualificationReasonToLeads do
  use Ecto.Migration

  def change do
    alter table(:leads) do
      add :icp_disqualification_reason, {:array, :string}, default: []
    end
  end
end
