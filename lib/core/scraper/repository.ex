defmodule Core.Scraper.Repository do
  @moduledoc """
  Database operations for scraped webpages.
  """

  alias Core.Repo
  alias Core.Scraper.ScrapedWebpage
  import Ecto.Query

  def save_scraped_content(url, content, links) do
    domain = URI.parse(url).host

    %ScrapedWebpage{}
    |> ScrapedWebpage.changeset(%{
      url: url,
      domain: domain,
      content: content,
      links: links
    })
    |> Repo.insert()
  end

  def get_by_url(url) do
    Repo.get_by(ScrapedWebpage, url: url)
  end

  def list_by_domain(domain) do
    Repo.all(from s in ScrapedWebpage, where: s.domain == ^domain)
  end
end
