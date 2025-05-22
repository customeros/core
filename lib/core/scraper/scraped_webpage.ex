defmodule Core.Scraper.ScrapedWebpage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scraped_webpages" do
    field(:url, :string)
    field(:domain, :string)
    field(:content, :string)
    field(:links, {:array, :string}, default: [])

    timestamps()
  end

  def changeset(scraped_webpage, attrs) do
    scraped_webpage
    |> cast(attrs, [:url, :domain, :content, :links])
    |> validate_required([:url, :domain, :content])
    |> unique_constraint(:url)
  end
end
