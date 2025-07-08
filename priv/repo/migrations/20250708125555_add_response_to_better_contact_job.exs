defmodule Core.Repo.Migrations.AddResponseToBetterContactJob do
  use Ecto.Migration

  def up do
    alter table(:better_contact_jobs) do
      add :response, :text
    end
  end

  def down do
    alter table(:better_contact_jobs) do
      remove :response
    end
  end
end
