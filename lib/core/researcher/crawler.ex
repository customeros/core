defmodule Core.Researcher.Crawler do
  @moduledoc """
  Crawl a website and scrape it's content starting from root domain.
  """
  require Logger

  @default_opts [
    max_depth: 2,
    max_pages: 100,
    delay: 100,
    concurrency: 5
  ]

  @doc """
  Starts crawler in supervised task, returns task for caller control.
  """
  @spec crawl_supervised(String.t(), keyword()) :: Task.t()
  def crawl_supervised(domain, opts \\ []) do
    Task.Supervisor.async(Core.TaskSupervisor, fn ->
      opts = Keyword.merge(@default_opts, opts)
      crawl(domain, opts)
    end)
  end

  defp crawl(domain, opts) when is_binary(domain) do
    case Core.Utils.DomainExtractor.extract_base_domain(domain) do
      {:ok, base_domain} ->
        # Start crawling with concurrent workers
        crawl_concurrent(%{
          queue: [{domain, 0}],
          visited: MapSet.new(),
          results: %{},
          base_domain: base_domain,
          max_depth: opts[:max_depth],
          max_pages: opts[:max_pages],
          delay: opts[:delay],
          concurrency: opts[:concurrency],
          active_tasks: 0,
          task_refs: MapSet.new()
        })

      {:error, reason} ->
        {:error, "Invalid domain: #{reason}"}
    end
  end

  defp crawl_concurrent(state) do
    cond do
      # No more work and no active tasks - we're done
      Enum.empty?(state.queue) and state.active_tasks == 0 ->
        Logger.info(
          "Crawling completed. Processed #{MapSet.size(state.visited)} pages."
        )

        {:ok, state.results}

      # We've hit max pages - wait for active tasks to finish
      MapSet.size(state.visited) >= state.max_pages and state.active_tasks == 0 ->
        Logger.info("Max pages reached. Crawling completed.")
        {:ok, state.results}

      # Start more tasks if we have queue items and available slots
      length(state.queue) > 0 and state.active_tasks < state.concurrency and
          MapSet.size(state.visited) < state.max_pages ->
        start_next_task_async(state)

      true ->
        wait_for_task_completion(state)
    end
  end

  defp start_next_task_async(%{queue: []} = state), do: crawl_concurrent(state)

  defp start_next_task_async(%{queue: [{url, depth} | rest]} = state) do
    # Skip if already visited or being processed
    if MapSet.member?(state.visited, url) do
      crawl_concurrent(%{state | queue: rest})
    else
      # Start async task for page processing
      task =
        Task.async(fn ->
          Logger.info("Crawling #{url} (depth: #{depth})")

          # Add delay to be nice to the server
          if state.delay > 0, do: Process.sleep(state.delay)

          case scrape_url(url) do
            {:ok, content} ->
              {:ok, url, depth, content}

            {:error, reason} ->
              Logger.warning("Failed to scrape #{url}: #{reason}")
              {:error, url, reason}
          end
        end)

      new_state = %{
        state
        | queue: rest,
          visited: MapSet.put(state.visited, url),
          active_tasks: state.active_tasks + 1,
          task_refs: MapSet.put(state.task_refs, task.ref)
      }

      crawl_concurrent(new_state)
    end
  end

  defp wait_for_task_completion(state) do
    receive do
      {ref, result} -> handle_task_result(state, ref, result)
      {:DOWN, ref, :process, _pid, _reason} -> handle_task_crash(state, ref)
    end
  end

  defp handle_task_result(state, ref, result) do
    if MapSet.member?(state.task_refs, ref) do
      state
      |> clean_up_task(ref)
      |> process_result(result)
      |> crawl_concurrent()
    else
      wait_for_task_completion(state)
    end
  end

  defp handle_task_crash(state, ref) do
    if MapSet.member?(state.task_refs, ref) do
      state
      |> clean_up_task(ref)
      |> crawl_concurrent()
    else
      wait_for_task_completion(state)
    end
  end

  defp clean_up_task(state, ref) do
    Process.demonitor(ref, [:flush])

    %{
      state
      | active_tasks: state.active_tasks - 1,
        task_refs: MapSet.delete(state.task_refs, ref)
    }
  end

  defp process_result(state, {:ok, url, depth, content}) do
    state
    |> add_results(url, content)
    |> queue_new_links(content, depth)
  end

  defp process_result(state, {:error, _url, _reason}), do: state

  defp add_results(state, url, content) do
    %{state | results: Map.put(state.results, url, content)}
  end

  defp queue_new_links(state, content, depth) do
    links =
      case content do
        %{links: links} when is_list(links) ->
          links

        content when is_binary(content) ->
          Core.Researcher.Webpages.LinkExtractor.extract_links(content)

        _ ->
          []
      end

    new_links = extract_new_links(links, depth, state)
    %{state | queue: state.queue ++ new_links}
  end

  defp extract_new_links(links, depth, state) do
    if depth >= state.max_depth do
      []
    else
      links
      |> Enum.filter(fn link ->
        !MapSet.member?(state.visited, link) &&
          same_domain?(link, state.base_domain)
      end)
      |> Enum.map(fn link -> {link, depth + 1} end)
    end
  end

  defp scrape_url(url) do
    case Core.Utils.UrlFormatter.to_https(url) do
      {:ok, valid_url} ->
        valid_url
        |> Core.Researcher.Scraper.scrape_webpage()

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp same_domain?(url, base_domain) when is_binary(base_domain) do
    case Core.Utils.DomainExtractor.extract_base_domain(url) do
      {:ok, url_domain} ->
        String.ends_with?(url_domain, base_domain)

      _ ->
        false
    end
  end
end
