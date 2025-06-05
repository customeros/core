defmodule Core.Repo.Migrations.AddHomepageScrapedToCompanies do
  use Ecto.Migration

  def up do
    alter table(:companies) do
      add(:homepage_scraped, :boolean, default: false, null: false)
    end
  end

  def down do
    alter table(:companies) do
      remove(:homepage_scraped)
    end
  end
end
