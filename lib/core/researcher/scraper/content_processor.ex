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

  alias Core.Researcher.Webpages

  # 1 min
  @default_timeout 60 * 1000

  @err_not_utf8 {:error, "content not utf-8"}
  @err_content_invalid {:error, "invalid content"}

  def handle_scraped_content_supervised(content, url) do
    Task.Supervisor.async(
      Core.TaskSupervisor,
      fn ->
        handle_scraped_content(content, url)
      end
    )
  end

  def handle_scraped_content(content, url) do
    with {:ok, sanitized_content} <- sanitize_content(content),
         {:ok, processed_data} <- process_webpage(url, sanitized_content) do
      _ = save_to_database(url, processed_data)
      {:ok, processed_data}
    else
      {:error, reason} -> {:error, reason}
    end
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

  defp process_webpage(url, content) do
    links = Webpages.LinkExtractor.extract_links(content)

    tasks = [
      Webpages.Classifier.classify_content_supervised(url, content),
      Webpages.IntentProfiler.profile_intent_supervised(url, content),
      Webpages.Summarizer.summarize_webpage_supervised(url, content)
    ]

    [classification_result, intent_result, summary_result] =
      Task.await_many(tasks, @default_timeout)

    with {:ok, classification} <- classification_result,
         {:ok, intent} <- intent_result,
         {:ok, summary} <- summary_result do
      {:ok,
       %{
         content: content,
         classification: classification,
         intent: intent,
         summary: summary,
         links: links
       }}
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
    case Webpages.save_scraped_content(
           url,
           content,
           links,
           classification,
           intent,
           summary
         ) do
      {:ok, saved_webpage} ->
        {:ok, saved_webpage}

      {:error, db_error} ->
        {:error, "Database save failed: #{inspect(db_error)}"}
    end
  end
end
