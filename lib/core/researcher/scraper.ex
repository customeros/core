defmodule Core.Researcher.Scraper do
  require OpenTelemetry.Tracer
  require Logger
  alias Core.Researcher.Scraper.Jina
  alias Core.Researcher.Scraper.Puremd
  alias Core.Researcher.Scraper.ContentProcessor
  alias Core.Researcher.Errors
  alias Core.Researcher.Webpages.Cleaner

  # 60 seconds
  @scraper_timeout 60 * 1000

  def scrape_webpage(url) do
    OpenTelemetry.Tracer.with_span "scraper.scrape_webpage" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      case Core.Researcher.ScrapedWebpages.get_by_url(url) do
        {:ok, existing_record} -> use_cached_content(existing_record)
        {:error, :not_found} -> fetch_and_process_webpage(url)
      end
    end
  end

  defp fetch_and_process_webpage(url) do
    with {:ok, content} <- fetch_webpage(url),
         {:ok, task} <- start_content_processing_task(content, url),
         result <- Task.await(task, @scraper_timeout) do
      result
    else
      {:error, reason} -> Errors.error(reason)
    end
  end

  defp start_content_processing_task(content, url) do
    # Capture OpenTelemetry context before starting supervised task
    current_ctx = OpenTelemetry.Ctx.get_current()

    case Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
           OpenTelemetry.Ctx.attach(current_ctx)
           ContentProcessor.handle_scraped_content(content, url)
         end) do
      {:ok, task} -> {:ok, task}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_webpage(url) do
    with {:error, _jina_reason} <- try_jina_service(url),
         {:error, puremd_reason} <- try_puremd_service(url) do
      handle_fetch_error(puremd_reason)
    else
      {:ok, content} ->
        clean_content =
          content
          |> Cleaner.process_markdown_webpage()

        {:ok, clean_content}
    end
  end

  defp handle_fetch_error({:http_error, message}) do
    Errors.error("HTTP Error: #{message}")
  end

  defp handle_fetch_error(reason) when is_binary(reason) do
    Errors.error(reason)
  end

  defp handle_fetch_error(reason) do
    Errors.error("Error: #{inspect(reason)}")
  end

  defp try_jina_service(url) do
    Logger.info("Attempting to fetch #{url} with Jina service")

    # Capture context before starting supervised task
    current_ctx = OpenTelemetry.Ctx.get_current()

    case Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
           OpenTelemetry.Ctx.attach(current_ctx)
           Jina.fetch_page(url)
         end) do
      {:ok, task} ->
        await_scraped_webpage(url, task, @scraper_timeout, "Jina webscraper")

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp try_puremd_service(url) do
    Logger.info("Attempting to fetch #{url} with PureMD service")

    current_ctx = OpenTelemetry.Ctx.get_current()

    case Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
           OpenTelemetry.Ctx.attach(current_ctx)
           Puremd.fetch_page(url)
         end) do
      {:ok, task} ->
        await_scraped_webpage(url, task, @scraper_timeout, "PureMD webscraper")

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp await_scraped_webpage(url, task, timeout, task_name) do
    case Task.yield(task, timeout) do
      {:ok, {:ok, content}} ->
        content
        |> validate_content()

      {:ok, {:error, reason}} ->
        Logger.warning("#{task_name} failed for #{url}: #{reason}")
        {:error, reason}

      {:ok, {:http_error, reason}} ->
        Logger.warning("#{task_name} failed for #{url}: #{reason}")
        {:error, reason}

      nil ->
        Task.shutdown(task)
        Errors.error(:webscraper_timeout)

      {:exit, reason} ->
        Errors.error(reason)

      _ ->
        {:error, :unknown}
    end
  end

  defp use_cached_content(record) do
    Logger.info("Using cached content for #{record.url}")

    # Return the full scraped data structure for consistency
    {:ok,
     %{
       content: record.content,
       classification: build_classification_from_record(record),
       intent: build_intent_from_record(record),
       summary: record.summary,
       links: record.links || []
     }}
  end

  defp validate_content(content) do
    cond do
      content == "" ->
        {:error, :no_content}

      String.contains?(content, "403 Forbidden") ->
        {:error, :unprocessable}

      String.contains?(content, "Robot Challenge") ->
        {:error, :unprocessable}

      String.contains?(content, "no content") ->
        {:error, :no_content}

      true ->
        {:ok, content}
    end
  end

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
