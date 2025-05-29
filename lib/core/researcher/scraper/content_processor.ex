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
    with {:ok, processed_data} <- process_webpage(url, content),
         {:ok, _saved_webpage} <- save_to_database(url, processed_data) do
      {:ok, processed_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

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
