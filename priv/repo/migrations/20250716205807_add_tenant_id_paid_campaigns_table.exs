defmodule Core.Repo.Migrations.AddTenantIdPaidCampaignsTable do
  use Ecto.Migration

  def change do
    alter table(:paid_campaigns) do
      add :tenant_id, :string, null: false
    end

    create index(:paid_campaigns, [:tenant_id])
    create unique_index(:paid_campaigns, [:tenant_id, :hash])
    drop_if_exists unique_index(:paid_campaigns, [:hash])
  end
end
