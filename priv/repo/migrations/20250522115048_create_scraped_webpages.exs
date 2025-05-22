defmodule Core.Repo.Migrations.CreateScrapedWebpages do
  use Ecto.Migration

  def change do
    create table(:scraped_webpages) do
      add :url, :string, null: false
      add :domain, :string, null: false
      add :content, :text, null: false
      add :links, {:array, :string}, default: []

      timestamps()
    end

    create unique_index(:scraped_webpages, [:url])
    create index(:scraped_webpages, [:domain])
  end
end
