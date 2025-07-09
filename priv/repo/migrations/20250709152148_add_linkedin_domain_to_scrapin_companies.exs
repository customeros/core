defmodule Core.Repo.Migrations.AddLinkedinDomainToScrapinCompanies do
  use Ecto.Migration

  def up do
    alter table(:scrapin_companies) do
      add :linkedin_domain, :text, after: :domain
    end
  end

  def down do
    alter table(:scrapin_companies) do
      remove :linkedin_domain
    end
  end
end
