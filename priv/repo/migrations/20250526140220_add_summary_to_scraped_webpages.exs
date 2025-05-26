defmodule Core.Repo.Migrations.AddSummaryToScrapedWebpages do
  use Ecto.Migration

  def up do
    alter table(:scraped_webpages) do
      add :summary, :text, null: true
    end
  end

  def down do
    alter table(:scraped_webpages) do
      remove :summary
    end
  end
end
