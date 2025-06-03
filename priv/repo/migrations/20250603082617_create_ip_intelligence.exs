defmodule Core.Repo.Migrations.CreateIpIntelligence do
  use Ecto.Migration

  def up do
    create table(:ip_intelligence, primary_key: false) do
      add :id, :string, primary_key: true
      add :ip, :string, null: false
      add :domain_source, :string
      add :domain, :string
      add :is_mobile, :boolean
      add :city, :string
      add :region, :string
      add :country, :string
      add :has_threat, :boolean
      timestamps(type: :utc_datetime)
    end

    create index(:ip_intelligence, [:ip])
    create index(:ip_intelligence, [:domain])
    create index(:ip_intelligence, [:domain_source])
    create index(:ip_intelligence, [:country])
  end

  def down do
    drop table(:ip_intelligence)
  end
end
