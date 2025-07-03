defmodule Core.Repo.Migrations.CreatePaidCampaignsTable do
  use Ecto.Migration

  def change do
    create table(:paid_campaigns, primary_key: false) do
      add :id, :string, primary_key: true, null: false
      add :platform, :string, null: false
      add :account_id, :string
      add :campaign_id, :string
      add :group_id, :string
      add :targeting_id, :string
      add :content_id, :string
      add :hash, :string, null: false
      add :first_seen_at, :utc_datetime
      add :last_seen_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:paid_campaigns, [:hash])
  end
end
