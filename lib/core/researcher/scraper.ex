defmodule Core.Researcher.Scraper do
  require Logger

  @error_unprocessable "unable to scrape webpage"
  # 1 min
  @default_scraper_timeout 60 * 1000

  defp jina_service,
    do: Application.get_env(:core, :jina_service, Core.External.Jina.Service)

  defp puremd_service,
    do:
      Application.get_env(:core, :puremd_service, Core.External.Puremd.Service)

  defp firecrawl_service,
    do:
      Application.get_env(:core, :firecrawl_service, Core.External.Firecrawl.Service)

  defp classify_service,
    do:
      Application.get_env(
        :core,
        :classify_service,
        Core.Researcher.Webpages.Classifier
      )

  defp profile_intent_service,
    do:
      Application.get_env(
        :core,
        :profile_intent_service,
        Core.Researcher.Webpages.IntentGenerator
      )

  def scrape_webpage(url) do
    case Core.Researcher.ScrapedWebpages.get_by_url(url) do
      {:error, :not_found} -> fetch_and_process_webpage(url)
      {:ok, existing_record} -> use_cached_content(existing_record)
    end
  end

  defp fetch_and_process_webpage(url, timeout \\ @default_scraper_timeout) do
    task =
      Task.Supervisor.async(Core.Researcher.Scraper.Supervisor, fn ->
        fetch_webpage_content(url)
        with {:error, _jina_reason} <- try_jina_service(url),
             {:error, _puremd_reason} <- try_puremd_service(url),
             {:error, firecrawl_reason} <- try_firecrawl_service(url) do
          {:error, "All services failed - #{firecrawl_reason}"}
        else
          {:ok, result} -> {:ok, result}
        end
      end)

    case Task.yield(task, timeout) do
      {:ok, result} ->
        result

      nil ->
        Task.Supervisor.terminate_child(
          Core.Researcher.Scraper.Supervisor,
          task.pid
        )

        {:error, "webpage_fetch_timeout"}

      {:exit, reason} ->
        {:error, "webpage_fetch_failed: #{inspect(reason)}"}
    end
  end

  defp fetch_webpage_content(url) do
    with {:error, _jina_reason} <- try_jina_service(url),
         {:error, puremd_reason} <- try_puremd_service(url) do
      handle_fetch_error(puremd_reason)
    else
      {:ok, result} -> {:ok, result}
    end
  end

  defp handle_fetch_error({:api_error, message}) do
    {:error, "API Error: #{message}"}
  end

  defp handle_fetch_error(reason) when is_binary(reason) do
    {:error, "Error: #{reason}"}
  end

  defp handle_fetch_error(reason) do
    {:error, "Error: #{inspect(reason)}"}
  end

  defp try_jina_service(url) do
    Logger.info("Attempting to fetch #{url} with Jina service")

    with {:ok, content} <- jina_service().fetch_page(url),
         {:ok, validated_content} <- validate_content(content) do
      handle_scraped_content(url, validated_content)
    else
      {:error, reason} ->
        error_message = format_error(reason)
        Logger.warning("Jina service failed for #{url}: #{error_message}")
        {:error, "Jina failed: #{error_message}"}
    end
  end

  defp try_puremd_service(url) do
    Logger.info("Attempting to fetch #{url} with Puremd service")

    with {:ok, content} <- puremd_service().fetch_page(url),
         {:ok, validated_content} <- validate_content(content) do
      handle_scraped_content(url, validated_content)
    else
      {:error, reason} ->
        error_message = format_error(reason)
        Logger.warning("Puremd service failed for #{url}: #{error_message}")
        {:error, "Puremd failed: #{error_message}"}
    end
  end

  defp try_firecrawl_service(url) do
    Logger.info("Attempting to fetch #{url} with Firecrawl service")

    with {:ok, content} <- firecrawl_service().fetch_page(url),
         {:ok, validated_content} <- validate_content(content) do
      handle_scraped_content(url, validated_content)
    else
      {:error, {:decode_error, reason}} -> log_and_return_error(url, "Failed to decode response: #{inspect(reason)}")
      {:error, {:api_error, status, body}} -> log_and_return_error(url, "API error #{status}: #{inspect(body)}")
      {:error, {:request_failed, reason}} -> log_and_return_error(url, "Request failed: #{inspect(reason)}")
      {:error, :empty_content} -> log_and_return_error(url, "Empty content received")
      {:error, {:invalid_format, response}} -> log_and_return_error(url, "Invalid response format: #{inspect(response)}")
      {:error, reason} -> log_and_return_error(url, format_error(reason))
    end
  end

  defp log_and_return_error(url, message) do
    Logger.warning("Firecrawl service failed for #{url}: #{message}")
    {:error, message}
  end

  defp use_cached_content(record) do
    Logger.info("Using cached content for #{record.url}")

    # Return the full scraped data structure for consistency
    {:ok,
     %{
       content: record.content,
       classification: build_classification_from_record(record),
       intent: build_intent_from_record(record),
       links: record.links || []
     }}
  end

  defp handle_scraped_content(url, content) do
    Logger.info("Processing scraped content for #{url}")

    with {:ok, processed_data} <- process_webpage(url, content),
         {:ok, _saved_webpage} <- save_to_database(url, processed_data) do
      {:ok, processed_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp save_to_database(url, %{
         content: content,
         classification: classification,
         intent: intent,
         links: links,
         summary: summary
       }) do
    case Core.Researcher.ScrapedWebpages.save_scraped_content(
           url,
           content,
           links,
           classification,
           intent,
           summary
         ) do
      {:ok, saved_webpage} ->
        Logger.info("Successfully saved webpage data for #{url}")
        {:ok, saved_webpage}

      {:error, db_error} ->
        Logger.error("Database save failed for #{url}: #{inspect(db_error)}")
        {:error, "Database save failed: #{inspect(db_error)}"}
    end
  end

  defp validate_content(content) do
    cond do
      content == "" ->
        {:error, @error_unprocessable}

      String.contains?(content, "403 Forbidden") ->
        {:error, @error_unprocessable}

      String.contains?(content, "Robot Challenge") ->
        {:error, @error_unprocessable}

      String.contains?(content, "no content") ->
        {:error, @error_unprocessable}

      true ->
        {:ok, content}
    end
  end

  defp process_webpage(url, content) do
    domain = extract_domain(url)

    clean_content =
      Core.Researcher.Webpages.Cleaner.process_markdown_webpage(content)

    # Start all 4 processes in parallel
    classification_task =
      Task.Supervisor.async(Core.Researcher.Scraper.Supervisor, fn ->
        classify_service().classify_webpage_content(domain, clean_content)
      end)

    intent_task =
      Task.Supervisor.async(Core.Researcher.Scraper.Supervisor, fn ->
        profile_intent_service().profile_webpage_intent(domain, clean_content)
      end)

    links_task =
      Task.Supervisor.async(Core.Researcher.Scraper.Supervisor, fn ->
        Core.Researcher.Webpages.LinkExtractor.extract_links(clean_content)
      end)

    summarize_task =
      Task.Supervisor.async(Core.Researcher.Scraper.Supervisor, fn ->
        Core.Researcher.Webpages.Summarizer.summarize_webpage(
          url,
          clean_content
        )
      end)

    # Wait for all tasks to complete
    with {:ok, classification} <-
           await_task(
             classification_task,
             @default_scraper_timeout,
             "classification"
           ),
         {:ok, intent} <-
           await_task(intent_task, @default_scraper_timeout, "intent"),
         links <- await_task(links_task, 10_000, "links"),
         {:ok, summary} <-
           await_task(summarize_task, @default_scraper_timeout, "summary") do
      {:ok,
       %{
         content: clean_content,
         classification: classification,
         intent: intent,
         links: links,
         summary: summary
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp await_task(task, timeout, task_name) do
    case Task.yield(task, timeout) do
      {:ok, result} ->
        result

      nil ->
        Task.Supervisor.terminate_child(
          Core.Researcher.Scraper.Supervisor,
          task.pid
        )

        {:error, "#{task_name}_timeout"}

      {:exit, reason} ->
        {:error, "#{task_name}_failed: #{inspect(reason)}"}
    end
  end

  defp extract_domain(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> url
    end
  end

  # Helper functions for building structs from database records
  defp format_error(%Mint.TransportError{reason: reason}),
    do: "Transport error: #{reason}"

  defp format_error(%{__struct__: struct_name} = error)
       when is_atom(struct_name) do
    "#{struct_name}: #{inspect(error)}"
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)

  defp build_classification_from_record(record) do
    if has_classification_data?(record) do
      %Core.Researcher.Webpages.Classification{
        primary_topic: record.primary_topic,
        secondary_topics: record.secondary_topics || [],
        solution_focus: record.solution_focus || [],
        content_type: parse_content_type(record.content_type),
        industry_vertical: record.industry_vertical,
        key_pain_points: record.key_pain_points || [],
        value_proposition: record.value_proposition,
        referenced_customers: record.referenced_customers || []
      }
    else
      nil
    end
  end

  defp build_intent_from_record(record) do
    if has_intent_data?(record) do
      %Core.Researcher.Webpages.Intent{
        problem_recognition: record.problem_recognition_score,
        solution_research: record.solution_research_score,
        evaluation: record.evaluation_score,
        purchase_readiness: record.purchase_readiness_score
      }
    else
      nil
    end
  end

  defp has_classification_data?(record) do
    not is_nil(record.primary_topic) or
      not is_nil(record.content_type) or
      not is_nil(record.industry_vertical)
  end

  defp has_intent_data?(record) do
    not is_nil(record.problem_recognition_score) or
      not is_nil(record.solution_research_score) or
      not is_nil(record.evaluation_score) or
      not is_nil(record.purchase_readiness_score)
  end

  defp parse_content_type(nil), do: :unknown

  defp parse_content_type(content_type) when is_binary(content_type) do
    String.to_existing_atom(content_type)
  rescue
    ArgumentError -> :unknown
  end
end
