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
  alias Core.Researcher.Webpages
  alias Core.Utils.Tracing
  alias Core.Utils.TaskAwaiter

  # 1 min
  @default_timeout 60 * 1000

  @err_not_utf8 {:error, "content not utf-8"}
  @err_content_invalid {:error, "invalid content"}

  def process_scraped_content(url, content) do
    content
    |> sanitize_content()
    |> extract_links()
    |> summarize_content(url)
    |> save_to_database(url)
  end

  defp sanitize_content(content) when is_binary(content) do
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

  defp extract_links({:ok, content}) do
    links = Webpages.LinkExtractor.extract_links(content)
    {:ok, content, links}
  end

  defp extract_links({:error, reason}), do: {:error, reason}

  defp summarize_content({:ok, content, links}, url) do
    OpenTelemetry.Tracer.with_span "content_processor.summarize_content" do
      Logger.metadata(module: __MODULE__, function: :summarize_content)

      Logger.info("Starting webpage summarization",
        url: url
      )

      task = Webpages.Summarizer.summarize_webpage_supervised(url, content)

      case TaskAwaiter.await(task, @default_timeout) do
        {:ok, summary} ->
          {:ok, content, links, summary}

        {:error, reason} ->
          Tracing.error(reason, "Webpage summary failed", url: url)

          {:ok, content, links, ""}
      end
    end
  end

  defp summarize_content({:error, reason}, _url), do: {:error, reason}

  defp save_to_database({:ok, content, links, summary}, url) do
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

  defp save_to_database({:error, reason}, _url), do: {:error, reason}
end
