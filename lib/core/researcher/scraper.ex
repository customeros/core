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

    Logger.info("Starting to scrape #{url}",
      url: url
    )

    case validate_url(url) do
      {:error, reason} ->
        {:error, reason}

      url ->
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
    url
    |> fetch_webpage()
    |> process_content(url)
  end

  defp validate_url(url) do
    case DomainExtractor.extract_base_domain(url) do
      {:ok, host} ->
        case PrimaryDomainFinder.primary_domain?(host) do
          {:ok, true} ->
            {:ok, url} = UrlFormatter.to_https(url)
            url

          {:ok, false} ->
            @err_invalid_url

          {:error, reason} ->
            Logger.info("#{url} is invalid, stopping scraper")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.info("#{url} is invalid, stopping scraper")
        {:error, reason}
    end
  end

  defp process_content({:ok, content}, url) do
    Logger.metadata(module: __MODULE__, function: :process_content)

    case ContentProcessor.process_scraped_content(url, content) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed processing scraped content for #{url}")
        {:error, reason}
    end
  end

  defp process_content({:error, reason}, _url), do: {:error, reason}

  defp fetch_webpage(url) do
    with {:error, _jina_reason} <- try_jina(url),
         {:error, _puremd_reason} <- try_puremd(url),
         {:error, firecrawl_reason} <- try_firecrawl(url) do
      handle_fetch_error(firecrawl_reason, url)
    else
      {:ok, content} -> {:ok, content}
    end
  end

  defp handle_fetch_error({:http_error, message}, url) do
    Logger.error("HTTP error while attempting to scrape #{url}: #{message}")
    err = "http error => message: #{message}"
    {:error, err}
  end

  defp handle_fetch_error(reason, url) when is_binary(reason) do
    Logger.error("Failed to scrape #{url}: #{reason}")
    {:error, reason}
  end

  defp handle_fetch_error(reason, url) do
    Logger.error("Failed to scrape #{url}: #{inspect(reason)}")
    err = "Error: #{inspect(reason)}"
    {:error, err}
  end

  defp try_jina(url) do
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

  defp try_firecrawl(url) do
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

  defp try_puremd(url) do
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
