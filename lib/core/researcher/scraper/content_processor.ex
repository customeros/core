defmodule Core.Researcher.Scraper.ContentProcessor do
  alias Core.Researcher.Errors
  alias Core.Researcher.Webpages

  # 1 min
  @default_timeout 60 * 1000

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
      # Try to save to database but don't fail if it errors
      _ = save_to_database(url, processed_data)
      {:ok, processed_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp sanitize_content(content) when is_binary(content) do
    # Remove null bytes and ensure valid UTF-8
    sanitized =
      content
      |> String.replace(<<0>>, "")  # Remove null bytes
      |> String.to_charlist()       # Convert to charlist to handle invalid UTF-8
      |> Enum.filter(&(&1 >= 0 and &1 <= 0x10FFFF))  # Keep only valid Unicode code points
      |> List.to_string()           # Convert back to string

    if String.valid?(sanitized) do
      {:ok, sanitized}
    else
      {:error, :invalid_utf8}
    end
  end

  defp sanitize_content(_), do: {:error, :invalid_content_type}

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
      {:error, reason} -> Errors.error(reason)
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
        {:ok, saved_webpage}

      {:error, db_error} ->
        {:error, "Database save failed: #{inspect(db_error)}"}
    end
  end
end
