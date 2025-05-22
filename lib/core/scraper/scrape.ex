defmodule Core.Scraper.Scrape do
  @spec scrape_webpage(String.t()) ::
          {:ok, String.t(), [String.t()]} | {:error, String.t()}

  def scrape_webpage(url) do
    case Core.External.Jina.Service.fetch_page(url) do
      {:ok, content} ->
        process_webpage(content)

      {:error, _reason} ->
        case Core.External.Puremd.Service.fetch_page(url) do
          {:ok, content} ->
            process_webpage(content)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp process_webpage(content) do
    clean_content = Core.Scraper.Clean.process_markdown_webpage(content)
    links = Core.Scraper.Links.extract_links(clean_content)
    {:ok, clean_content, links}
  end
end
