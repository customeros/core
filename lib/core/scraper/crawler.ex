defmodule Core.Scraper.Crawler do
  require Logger

  @default_opts [
    max_depth: 2,
    max_pages: 100,
    delay: 100  # ms between requests
  ]
  
  def start(domain, opts \\ []) do
    base_domain = Core.Utils.Domain.extract_base_domain(domain)
    opts = Keyword.merge(@default_opts, opts)
    
    # Start crawling with initial state
    crawl(%{
      queue: [{domain, 0}],  # {url, depth}
      visited: MapSet.new(),
      results: %{},
      base_domain: base_domain,
      max_depth: opts[:max_depth],
      max_pages: opts[:max_pages],
      delay: opts[:delay]
    })
  end
  
  defp crawl(%{queue: []} = state) do
    Logger.info("Crawling completed. Processed #{MapSet.size(state.visited)} pages.")
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
        {:ok, content, links} ->
          # Add a small delay to be nice to the server
          if state.delay > 0, do: Process.sleep(state.delay)
          
          # Update state
          new_state = %{state | 
            visited: MapSet.put(state.visited, url),
            results: Map.put(state.results, url, content),
            queue: queue_new_links(rest, links, depth, state)
          }
          
          # Continue crawling
          crawl(new_state)
          
        {:error, reason} ->
          Logger.warn("Failed to scrape #{url}: #{reason}")
          crawl(%{state | queue: rest})
      end
    end
  end
  
  # Helper function to safely format error messages
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason) when is_atom(reason), do: to_string(reason)
  defp format_error(%{__struct__: struct_type} = error) do
    "#{inspect(struct_type)} with reason: #{inspect(Map.get(error, :reason, "unknown"))}"
  end
  defp format_error(error), do: inspect(error)
  
  defp scrape_url(url) do
    try do
      with {:ok, valid_url} <- Core.Utils.Domain.to_https(url),
           {:ok, content, links} <- Core.Scraper.Scrape.scrape_webpage_with_jina(valid_url) do
        {:ok, content, links}
      else
        {:error, reason} -> {:error, reason}
      end
    rescue
      e ->
        # Convert exceptions to error tuples
        {:error, Exception.message(e)}
    catch
      kind, reason ->
        # Catch other errors (throw, exit)
        {:error, "#{kind}: #{inspect(reason)}"}
    end
  end
  
  defp queue_new_links(queue, _links, depth, %{max_depth: max_depth}) when depth >= max_depth do
    queue
  end
  
  defp queue_new_links(queue, links, depth, state) do
    links
    |> Enum.filter(fn link -> 
      !MapSet.member?(state.visited, link) && same_domain?(link, state.base_domain)
    end)
    |> Enum.map(fn link -> {link, depth + 1} end)
    |> Enum.concat(queue)
  end
  
  defp same_domain?(url, base_domain) do
    url_domain = Core.Utils.Domain.extract_base_domain(url)
    String.ends_with?(url_domain, base_domain)
  end
  
end
