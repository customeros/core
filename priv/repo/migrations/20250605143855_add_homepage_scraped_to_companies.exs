defmodule Core.Repo.Migrations.AddHomepageScrapedToCompanies do
  use Ecto.Migration

  def change do
    up do
      alter table(:companies) do
        add :homepage_scraped, :boolean, default: false, null: false
      end
    end

    down do
      alter table(:companies) do
        remove :homepage_scraped
      end
    end
  end
end
