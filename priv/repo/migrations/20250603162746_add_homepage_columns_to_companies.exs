defmodule Core.Repo.Migrations.AddHomepageColumnsToCompanies do
  use Ecto.Migration

  def up do
    alter table(:companies) do
      add :domain_scrape_attempts, :integer, default: 0, null: false
    end

    # Create index for efficient querying of companies that need domain scraping
    create index(:companies, [:domain_scrape_attempts, :domain_scrape_attempt_at])
  end

  def down do
    # Drop index first
    drop index(:companies, [:domain_scrape_attempts, :domain_scrape_attempt_at])

    # Remove column
    alter table(:companies) do
      remove :domain_scrape_attempts
    end
  end
end
