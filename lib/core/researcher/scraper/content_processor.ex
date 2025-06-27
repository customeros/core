defmodule Core.Researcher.Scraper.ContentProcessor do
  @moduledoc """
  Processes and analyzes scraped webpage content.

  This module handles:
  * Content sanitization and validation
  * Parallel processing of webpage analysis
  * Content classification and intent profiling
  * Webpage summarization
  * Link extraction and processing
  * Database persistence of processed content

  It coordinates multiple analysis tasks (classification,
  intent profiling, summarization) in parallel and manages
  the overall content processing pipeline, including
  sanitization and storage of the results.
  """
  require Logger
  require OpenTelemetry.Tracer

  alias Core.Utils.Tracing
  alias Core.Crm.Companies
  alias Core.Utils.TaskAwaiter
  alias Core.Researcher.Webpages
  alias Core.Utils.DomainExtractor

  # 1 min
  @default_timeout 60 * 1000

  @err_not_utf8 {:error, "content not utf-8"}
  @err_content_invalid {:error, "invalid content"}

  def process_scraped_content(url, content) do
    with {:ok, clean_content} <- sanitize_content(content),
         {:ok, links} <- extract_links(clean_content),
         :ok <- create_companies_from_links(url, links),
         {:ok, summary} <-
           summarize_content(url, clean_content) do
      save_to_database(url, clean_content, links, summary)
    else
      {:error, reason} ->
        Tracing.error(reason, "Process scraped content failed", url: url)
    end
  end

  defp sanitize_content(content) when is_binary(content) do
    Logger.info("Sanitizing content...")

    sanitized =
      content
      |> String.replace(<<0>>, "")
      |> String.to_charlist()
      |> Enum.filter(&(&1 >= 0 and &1 <= 0x10FFFF))
      |> List.to_string()

    if String.valid?(sanitized) do
      {:ok, sanitized}
    else
      @err_not_utf8
    end
  end

  defp sanitize_content(_), do: @err_content_invalid

  defp extract_links(content) do
    links = Webpages.LinkExtractor.extract_links(content)
    {:ok, links}
  end

  defp create_companies_from_links(url, links) do
    Logger.info("Processing links...",
      url: url
    )

    base_url = DomainExtractor.extract_base_domain(url)

    links
    |> Enum.map(&DomainExtractor.extract_base_domain/1)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == base_url))
    |> Enum.each(&Companies.get_or_create_by_domain/1)
  end

  defp summarize_content(url, content) do
    OpenTelemetry.Tracer.with_span "content_processor.summarize_content" do
      Logger.metadata(module: __MODULE__, function: :summarize_content)

      Logger.info("Starting webpage summarization",
        url: url
      )

      task = Webpages.Summarizer.summarize_webpage_supervised(url, content)

      case TaskAwaiter.await(task, @default_timeout) do
        {:ok, summary} ->
          {:ok, summary}

        {:error, reason} ->
          Tracing.error(reason, "Webpage summary failed", url: url)

          {:ok, ""}
      end
    end
  end

  defp save_to_database(url, content, links, summary) do
    OpenTelemetry.Tracer.with_span "content_processor.save_to_database" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      case Webpages.save_scraped_content(
             url,
             content,
             links,
             summary
           ) do
        {:ok, _saved_webpage} ->
          Logger.info("#{url} saved to database")
          {:ok, content}

        {:error, db_error} ->
          Tracing.error(db_error)

          Logger.error("Failed to save webpage to database",
            reason: "#{inspect(db_error)}",
            url: url
          )

          {:error, "Database save failed: #{inspect(db_error)}"}
      end
    end
  end
end
