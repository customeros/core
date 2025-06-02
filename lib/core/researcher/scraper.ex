defmodule Core.Researcher.Scraper do
  @moduledoc """
  Coordinates webpage scraping and content processing.

  This module manages:
  * Multi-service webpage scraping (Jina, Firecrawl, PureMD)
  * Content validation and cleaning
  * Caching and retrieval of scraped content
  * Parallel processing of webpage content
  * Error handling and timeout management
  * OpenTelemetry tracing and logging

  It implements a fallback strategy across multiple scraping
  services and coordinates the entire scraping pipeline,
  from fetching to processing and storage. The module
  includes robust error handling and supports both
  supervised and unsupervised content processing.
  """

  require OpenTelemetry.Tracer
  require Logger
  alias Core.Researcher.Scraper.Jina
  alias Core.Researcher.Scraper.Puremd
  alias Core.Researcher.Webpages.Cleaner
  alias Core.Researcher.Scraper.Firecrawl
  alias Core.Researcher.Scraper.ContentProcessor

  # 60 seconds
  @scraper_timeout 60 * 1000

  @err_no_content {:error, :no_content}
  @err_invalid_url {:error, :invalid_url}
  @err_unprocessable {:error, :unprocessable}
  @err_url_not_provided {:error, :url_not_provided}
  @err_webscraper_timed_out {:error, "webscraper timed out"}
  @err_unexpected_response {:error, "webscraper returned unexpected response"}

  def scrape_webpage(url)
      when is_binary(url) and byte_size(url) > 0 do
    OpenTelemetry.Tracer.with_span "scraper.scrape_webpage" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      case Core.Researcher.Webpages.get_by_url(url) do
        {:ok, existing_record} -> use_cached_content(existing_record)
        {:error, :not_found} -> fetch_and_process_webpage(url)
      end
    end
  end

  def scrape_webpage(""), do: @err_url_not_provided
  def scrape_webpage(nil), do: @err_url_not_provided
  def scrape_webpage(_), do: @err_invalid_url

  defp fetch_and_process_webpage(url) do
    with {:ok, content} <- fetch_webpage(url),
         task <- start_content_processing_task(content, url),
         result <- Task.await(task, @scraper_timeout) do
      result
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_content_processing_task(content, url) do
    # Capture OpenTelemetry context before starting supervised task
    current_ctx = OpenTelemetry.Ctx.get_current()

    # Changed from start_child to async - returns Task struct directly
    Task.Supervisor.async(Core.TaskSupervisor, fn ->
      OpenTelemetry.Ctx.attach(current_ctx)
      ContentProcessor.handle_scraped_content(content, url)
    end)
  end

  defp fetch_webpage(url) do
    with {:error, _jina_reason} <- try_jina(url),
         {:error, _firecrawl_reason} <- try_firecrawl(url),
         {:error, puremd_reason} <- try_puremd(url) do
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
    err = "http error => message: #{message}"
    {:error, err}
  end

  defp handle_fetch_error(reason) when is_binary(reason) do
    {:error, reason}
  end

  defp handle_fetch_error(reason) do
    err = "Error: #{inspect(reason)}"
    {:error, err}
  end

  defp try_jina(url) do
    Logger.info("Attempting to fetch #{url} with Jina service")

    current_ctx = OpenTelemetry.Ctx.get_current()

    task =
      Task.Supervisor.async(Core.TaskSupervisor, fn ->
        OpenTelemetry.Ctx.attach(current_ctx)
        Jina.fetch_page(url)
      end)

    await_scraped_webpage(url, task, @scraper_timeout, "Jina webscraper")
  end

  defp try_firecrawl(url) do
    current_ctx = OpenTelemetry.Ctx.get_current()

    task =
      Task.Supervisor.async(Core.TaskSupervisor, fn ->
        OpenTelemetry.Ctx.attach(current_ctx)
        Firecrawl.fetch_page(url)
      end)

    await_scraped_webpage(url, task, @scraper_timeout, "Firecrawl webscraper")
  end

  defp try_puremd(url) do
    current_ctx = OpenTelemetry.Ctx.get_current()

    task =
      Task.Supervisor.async(Core.TaskSupervisor, fn ->
        OpenTelemetry.Ctx.attach(current_ctx)
        Puremd.fetch_page(url)
      end)

    await_scraped_webpage(url, task, @scraper_timeout, "PureMD webscraper")
  end

  defp await_scraped_webpage(url, task, timeout, task_name) do
    case Task.yield(task, timeout) do
      {:ok, {:ok, content}} when is_binary(content) ->
        content
        |> validate_content()

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:ok, _unexpected} ->
        @err_unexpected_response

      nil ->
        Task.shutdown(task)
        @err_webscraper_timed_out

      {:exit, reason} ->
        Logger.error("#{task_name} crashed for #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp use_cached_content(record) do
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
        @err_no_content

      String.contains?(content, "403 Forbidden") ->
        @err_unprocessable

      String.contains?(content, "Robot Challenge") ->
        @err_unprocessable

      String.contains?(content, "no content") ->
        @err_no_content

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
