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
  alias Researcher.Scraper.Filter
  alias Core.Researcher.Webpages
  alias Core.Researcher.Webpages.Classifier
  alias Core.Utils.PrimaryDomainFinder
  alias Core.Utils.DomainExtractor
  alias Core.Utils.UrlFormatter
  alias Core.Researcher.Scraper.ContentProcessor
  alias Core.Researcher.Scraper.Jina
  alias Core.Researcher.Scraper.Puremd
  alias Core.Researcher.Scraper.Firecrawl

  # 60 seconds
  @scraper_timeout 60 * 1000

  @err_no_content {:error, :no_content}
  @err_invalid_url {:error, :invalid_url}
  @err_unprocessable {:error, :unprocessable}
  @err_url_not_provided {:error, :url_not_provided}
  @err_webscraper_timed_out {:error, "webscraper timed out"}
  @err_unexpected_response {:error, "webscraper returned unexpected response"}

  def scrape_webpage(url) when is_binary(url) and byte_size(url) > 0 do
    Logger.metadata(module: __MODULE__, function: :scrape_webpage)

    case validate_url(url) do
      {:error, reason} ->
        {:error, reason}

      url ->
        Logger.info("Starting to scrape #{url}",
          url: url
        )

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
    OpenTelemetry.Tracer.with_span "scraper.fetch_and_process_webpage" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      url
      |> fetch_webpage()
      |> process_content(url)
      |> classify_content(url)
    end
  end

  defp validate_url(url) do
    with {:ok, true} <- Filter.should_scrape?(url),
         {:ok, host} <- DomainExtractor.extract_base_domain(url),
         {:ok, true} <- PrimaryDomainFinder.primary_domain?(host),
         {:ok, base_url} <- UrlFormatter.get_base_url(url),
         {:ok, clean_url} <- UrlFormatter.to_https(base_url) do
      clean_url
    else
      {:ok, false} ->
        @err_invalid_url

      {:error, reason} ->
        Logger.info("#{url} is invalid, stopping scraper")
        {:error, reason}
    end
  end

  defp process_content({:ok, content}, url) do
    OpenTelemetry.Tracer.with_span "scraper.process_content" do
      Logger.metadata(module: __MODULE__, function: :process_content)

      case ContentProcessor.process_scraped_content(url, content) do
        {:ok, content} ->
          {:ok, content}

        {:error, reason} ->
          Logger.error(
            "Failed processing scraped content",
            url: url,
            reason: reason
          )

          Tracing.error(reason)

          {:error, reason}
      end
    end
  end

  defp process_content({:error, reason}, _url), do: {:error, reason}

  defp fetch_webpage(url) do
    OpenTelemetry.Tracer.with_span "scraper.fetch_webpage" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      with {:error, _jina_reason} <- try_jina(url),
           {:error, _puremd_reason} <- try_puremd(url),
           {:error, firecrawl_reason} <- try_firecrawl(url) do
        handle_fetch_error(firecrawl_reason, url)
      else
        {:ok, content} -> {:ok, content}
      end
    end
  end

  defp classify_content({:ok, content}, url) do
    OpenTelemetry.Tracer.with_span "scraper.classify_content" do
      task = Classifier.classify_content_supervised(url, content)
      results = Task.yield(task, @scraper_timeout)

      case results do
        {:ok, {:ok, classification}} ->
          Webpages.update_classification(url, classification)
          {:ok, content}

        {:ok, {:error, reason}} ->
          Tracing.error(reason)
          {:error, reason}

        {:exit, reason} ->
          Tracing.error(reason)
          {:error, reason}

        nil ->
          Tracing.error(:timeout)
          {:error, :timeout}
      end
    end
  end

  defp classify_content({:error, reason}, _url), do: {:error, reason}

  defp handle_fetch_error({:http_error, message}, url) do
    Logger.error("HTTP error while attempting to scrape #{url}: #{message}",
      url: url,
      reason: :http_error,
      message: message
    )

    err = "http error => message: #{message}"
    Tracing.error(err)
    {:error, err}
  end

  defp handle_fetch_error(reason, url) when is_binary(reason) do
    Logger.error("Failed to scrape #{url}", url: url, reason: reason)
    Tracing.error(reason)
    {:error, reason}
  end

  defp handle_fetch_error(reason, url) do
    Logger.error("Failed to scrape #{url}",
      url: url,
      reason: "#{inspect(reason)}"
    )

    Tracing.error(reason)
    err = "Error: #{inspect(reason)}"
    {:error, err}
  end

  defp try_jina(url) do
    OpenTelemetry.Tracer.with_span "scraper.try_jina" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      Logger.metadata(module: __MODULE__, function: :try_jina)

      Logger.info("Starting to scrape #{url} with Jina",
        url: url
      )

      task =
        Task.Supervisor.async(Core.TaskSupervisor, fn ->
          Jina.fetch_page(url)
        end)

      await_scraped_webpage(url, task, @scraper_timeout, "Jina webscraper")
    end
  end

  defp try_firecrawl(url) do
    OpenTelemetry.Tracer.with_span "scraper.try_firecrawl" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      Logger.metadata(module: __MODULE__, function: :try_firecrawl)

      Logger.info("Starting to scrape #{url} with Firecrawl",
        url: url
      )

      task =
        Task.Supervisor.async(Core.TaskSupervisor, fn ->
          Firecrawl.fetch_page(url)
        end)

      await_scraped_webpage(url, task, @scraper_timeout, "Firecrawl webscraper")
    end
  end

  defp try_puremd(url) do
    OpenTelemetry.Tracer.with_span "scraper.try_puremd" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      Logger.metadata(module: __MODULE__, function: :try_puremd)

      Logger.info("Starting to scrape #{url} with PureMD",
        url: url
      )

      task =
        Task.Supervisor.async(Core.TaskSupervisor, fn ->
          Puremd.fetch_page(url)
        end)

      await_scraped_webpage(url, task, @scraper_timeout, "PureMD webscraper")
    end
  end

  defp await_scraped_webpage(url, task, timeout, task_name) do
    case Task.yield(task, timeout) do
      {:ok, {:ok, content}} when is_binary(content) ->
        validate_content(content)

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
       summary: record.summary,
       links: record.links || []
     }}
  end

  defp validate_content(content) do
    cond do
      content == "" ->
        @err_no_content

      String.contains?(content, "403") and
          String.contains?(content, "Forbidden") ->
        @err_unprocessable

      String.contains?(content, "Robot Challenge") ->
        @err_unprocessable

      String.contains?(content, "no content") ->
        @err_no_content

      String.contains?(content, "Attention Required! | Cloudflare") ->
        @err_unprocessable

      String.contains?(content, "Why have I been blocked?") ->
        @err_unprocessable

      String.contains?(content, "Privacy error") ->
        @err_unprocessable

      true ->
        {:ok, content}
    end
  end
end
