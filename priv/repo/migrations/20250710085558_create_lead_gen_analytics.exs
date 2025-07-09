defmodule Core.Repo.Migrations.CreateLeadGenAnalytics do
  use Ecto.Migration

  def change do
    create table(:analytics_lead_generation, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :bucket_start_at, :utc_datetime, null: false
      add :tenant_id, :string, null: false
      add :sessions, :integer, null: false
      add :identified_sessions, :integer, null: false
      add :icp_fit_sessions, :integer, null: false
      add :unique_companies, :integer, null: false
      add :new_icp_fit_leads, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:analytics_lead_generation, [:tenant_id, :bucket_start_at])
  end
end
