defmodule Core.Repo.Migrations.AddNewCompaniesToAnalyticsLeadGen do
  use Ecto.Migration

  def change do
    alter table(:analytics_lead_generation) do
      add :unique_new_companies, :integer, null: false, default: 0
    end
  end
end
