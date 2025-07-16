defmodule Core.Repo.Migrations.AddTenantIdUtmCampaignsTable do
  use Ecto.Migration

  def change do
    alter table(:utm_campaigns) do
      add :tenant_id, :string, null: false
    end

    create index(:utm_campaigns, [:tenant_id])
    create unique_index(:utm_campaigns, [:tenant_id, :utm_hash])
    drop_if_exists unique_index(:utm_campaigns, [:utm_hash])
  end
end
