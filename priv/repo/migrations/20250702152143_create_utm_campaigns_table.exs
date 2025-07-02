defmodule Core.Repo.Migrations.CreateUtmCampaignsTable do
  use Ecto.Migration

  def change do
    create table(:utm_campaigns, primary_key: false) do
      add :id, :string, primary_key: true, null: false
      add :utm_source, :string
      add :utm_medium, :string
      add :utm_campaign, :string
      add :utm_term, :string
      add :utm_content, :string
      add :utm_hash, :string, null: false
      add :first_seen_at, :utc_datetime
      add :last_seen_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:utm_campaigns, [:utm_hash])
  end
end
