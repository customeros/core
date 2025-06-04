defmodule Core.WebTracker.SessionAnalyzer do
  @moduledoc """
  Analyzes web sessions to determine lead stage and other attributes.
  """

  require Logger
  alias Core.Researcher.Webpages
  alias Core.WebTracker.Events
  alias Core.Researcher.Scraper
  alias Core.WebTracker.Sessions
  alias Core.WebTracker.IpIdentifier.IpIntelligence

  @analysis_timeout 60 * 1000

  def start(session_id) do
    Task.Supervisor.start_child(
      Core.TaskSupervisor,
      fn ->
        analyze_session(session_id)
      end
    )
  end

  def analyze_session(session_id) do
    session_id
    |> session_details()
    |> determine_lead_stage()
  end

  defp session_details(session_id) do
    Logger.metadata(module: __MODULE__, function: :session_details)

    Logger.info("Starting new lead pipeline",
      session_id: session_id
    )

    with {:ok, session} <- Sessions.get_session_by_id(session_id),
         {:ok, domain} <- IpIntelligence.get_domain_by_ip(session.ip),
         {:ok, visited_pages} <- Events.get_visited_pages(session_id) do
      {:ok, domain, visited_pages}
    else
      {:error, :not_found} ->
        Logger.error(
          "Analyze session error: #{session_id} does not exist with events"
        )

        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Analyze session error: #{reason}")
        {:error, reason}
    end
  end

  defp determine_lead_stage({:ok, _visitor_domain, visited_pages}) do
    analysis_results =
      Enum.map(visited_pages, fn page ->
        analyze_webpage(page)
      end)

    stage = calculate_stage(analysis_results)
    {:ok, stage}
  end

  defp determine_lead_stage({:error, :not_found}),
    do: {:error, :session_not_found}

  defp determine_lead_stage({:error, reason}), do: {:error, reason}

  defp calculate_stage(_analysis) do
  end

  defp analyze_webpage(url) do
    url
    |> get_webpage_content()
    |> process_webpage_content()
    |> save_analysis()
  end

  defp get_webpage_content(url) do
    case Scraper.scrape_webpage(url) do
      {:ok, content} -> {:ok, url, content}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_webpage_content({:ok, url, content}) do
    tasks = [
      Webpages.Classifier.classify_content_supervised(url, content),
      Webpages.IntentProfiler.profile_intent_supervised(url, content)
    ]

    [classification_result, intent_result] =
      Task.await_many(tasks, @analysis_timeout)

    with {:ok, classification} <- classification_result,
         {:ok, intent} <- intent_result do
      {:ok,
       %{
         url: url,
         classification: classification,
         intent: intent
       }}
    else
      {:error, result} -> {:error, result}
    end
  end

  defp process_webpage_content({:error, :session_not_found}),
    do: {:error, :session_not_found}

  defp process_webpage_content({:error, reason}), do: {:error, reason}

  defp save_analysis(_url) do
  end
end
