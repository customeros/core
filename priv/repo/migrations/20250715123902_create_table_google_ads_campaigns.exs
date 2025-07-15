defmodule Core.Repo.Migrations.CreateTableGoogleAdsCampaigns do
  use Ecto.Migration

  def change do
    create table(:google_ads_campaigns) do
      add :tenant_id, :string, null: false
      add :manager_customer_id, :string, null: false
      add :client_customer_id, :string, null: false
      add :campaign_id, :string, null: false
      add :name, :string, null: false
      add :status, :string
      add :advertising_channel_type, :string
      add :advertising_channel_sub_type, :string
      add :start_date, :date
      add :end_date, :date
      add :optimization_score, :decimal
      add :raw_data, :map

      timestamps()
    end

    # Composite index for efficient upserts and lookups
    create unique_index(:google_ads_campaigns, [
             :tenant_id,
             :manager_customer_id,
             :client_customer_id,
             :campaign_id
           ])

    # Index for tenant-based queries
    create index(:google_ads_campaigns, [:tenant_id])

    # Index for customer-based queries
    create index(:google_ads_campaigns, [:client_customer_id])
  end
end
