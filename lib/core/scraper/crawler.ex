defmodule Core.Scraper.Crawler do
  require Logger

  @default_opts [
    max_depth: 2,
    max_pages: 100,
    # ms between requests
    delay: 100
  ]

  def start(domain, opts \\ []) do
    case Core.Utils.Domain.extract_base_domain(domain) do
      {:ok, base_domain} ->
        opts = Keyword.merge(@default_opts, opts)

        # Start crawling with initial state
        crawl(%{
          queue: [{domain, 0}],
          visited: MapSet.new(),
          results: %{},
          base_domain: base_domain,
          max_depth: opts[:max_depth],
          max_pages: opts[:max_pages],
          delay: opts[:delay]
        })

      {:error, reason} ->
        {:error, "Invalid domain: #{reason}"}
    end
  end

  defp crawl(%{queue: []} = state) do
    Logger.info(
      "Crawling completed. Processed #{MapSet.size(state.visited)} pages."
    )

    {:ok, state.results}
  end

  defp crawl(%{queue: [{url, depth} | rest]} = state) do
    # Skip if already visited or reached limits
    if MapSet.member?(state.visited, url) ||
         MapSet.size(state.visited) >= state.max_pages do
      # Process next URL
      crawl(%{state | queue: rest})
    else
      # Process this URL
      Logger.info("Crawling #{url} (depth: #{depth})")

      case scrape_url(url) do
        {:ok, content} ->
          # Add a small delay to be nice to the server
          if state.delay > 0, do: Process.sleep(state.delay)

          # Update state
          new_state = %{
            state
            | visited: MapSet.put(state.visited, url),
              results: Map.put(state.results, url, content),
              queue: queue_new_links(rest, content.links, depth, state)
          }

          # Continue crawling
          crawl(new_state)

        {:error, reason} ->
          Logger.warning("Failed to scrape #{url}: #{reason}")
          crawl(%{state | queue: rest})
      end
    end
  end

  defp scrape_url(url) do
    try do
      with {:ok, valid_url} <- Core.Utils.Domain.to_https(url) do
        Core.Scraper.Scrape.scrape_webpage(valid_url)
      else
        {:error, reason} -> {:error, reason}
      end
    rescue
      e -> {:error, Exception.message(e)}
    catch
      kind, reason -> {:error, "#{kind}: #{inspect(reason)}"}
    end
  end

  defp queue_new_links(queue, _links, depth, %{max_depth: max_depth})
       when depth >= max_depth do
    queue
  end

  defp queue_new_links(queue, links, depth, state) do
    links
    |> Enum.filter(fn link ->
      !MapSet.member?(state.visited, link) &&
        same_domain?(link, state.base_domain)
    end)
    |> Enum.map(fn link -> {link, depth + 1} end)
    |> Enum.concat(queue)
  end

  defp same_domain?(url, base_domain) when is_binary(base_domain) do
    case Core.Utils.Domain.extract_base_domain(url) do
      {:ok, url_domain} ->
        String.ends_with?(url_domain, base_domain)

      _ ->
        false
    end
  end
end
