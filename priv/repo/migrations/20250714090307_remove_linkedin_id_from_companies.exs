defmodule Core.Repo.Migrations.RemoveLinkedinIdFromCompanies do
  use Ecto.Migration

  def up do
    alter table(:companies) do
      remove :linkedin_id
    end
  end

  def down do
    alter table(:companies) do
      add :linkedin_id, :string
    end
  end
end
