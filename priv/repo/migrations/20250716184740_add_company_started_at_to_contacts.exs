defmodule Core.Repo.Migrations.AddCompanyStartAtToContacts do
  use Ecto.Migration

  def up do
    alter table(:contacts) do
      add :company_started_at, :utc_datetime, null: true, after: :job_ended_at
    end
  end

  def down do
    alter table(:contacts) do
      remove :company_started_at
    end
  end
end
