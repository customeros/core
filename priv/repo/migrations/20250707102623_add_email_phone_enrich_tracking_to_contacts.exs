defmodule Core.Repo.Migrations.AddEmailPhoneEnrichTrackingToContacts do
  use Ecto.Migration

  def up do
    alter table(:contacts) do
      add :email_enrich_requested_at, :utc_datetime
      add :phone_enrich_requested_at, :utc_datetime
    end

    create index(:contacts, [:email_enrich_requested_at])
    create index(:contacts, [:phone_enrich_requested_at])
  end

  def down do
    drop index(:contacts, [:phone_enrich_requested_at])
    drop index(:contacts, [:email_enrich_requested_at])

    alter table(:contacts) do
      remove :phone_enrich_requested_at
      remove :email_enrich_requested_at
    end
  end
end
