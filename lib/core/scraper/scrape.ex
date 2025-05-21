defmodule Core.Scraper.Scrape do

  def scrape_webpage_with_jina(url) do
    case Core.External.Jina.Service.fetch_page(url) do
      {:ok, content} -> 
        clean_content = Core.Scraper.Clean.process_markdown_webpage(content)
        links = Core.Scraper.Links.extract_links(clean_content)
        {:ok, clean_content, links}

      {:error, reason} -> {:error, reason}
    end
  end

end
