defmodule Core.Repo.Migrations.ChangeUrlInScrapedWebpages do
  use Ecto.Migration

  def up do
    alter table(:scraped_webpages) do
      modify :url, :string, size: 2048
    end
  end

  def down do
    alter table(:scraped_webpages) do
      modify :url, :string, size: 255
    end
  end
end
