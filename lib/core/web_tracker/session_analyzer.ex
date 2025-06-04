defmodule Core.WebTracker.SessionAnalyzer do
  @moduledoc """
  Web session post processing and analysis to determine where the visitor is in their buying journey.
  """

  require Logger
  alias Core.Crm.Leads
  alias Core.Researcher.Webpages.ScrapedWebpage
  alias Core.WebTracker.StageIdentifier
  alias Core.Researcher.Webpages
  alias Core.WebTracker.Events
  alias Core.Researcher.Scraper
  alias Core.WebTracker.Sessions

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
    Logger.info("Starting session analysis for #{session_id}",
      session_id: session_id
    )

    session_id
    |> session_details()
    |> determine_lead_stage()
  end

  defp session_details(session_id) do
    Logger.metadata(module: __MODULE__, function: :session_details)

    Logger.info("Aggregating web session details for #{session_id}",
      session_id: session_id
    )

    with {:ok, session} <- Sessions.get_session_by_id(session_id),
         {:ok, visited_pages} <- Events.get_visited_pages(session_id) do
      {:ok, session.tenant_id, visited_pages, session.company_id}
    else
      {:error, :not_found} ->
        Logger.error(
          "Analyze session error: #{session_id} does not exist with events"
        )

        {:error, :not_found}
    end
  end

  defp determine_lead_stage({:ok, tenant_id, visited_pages, visitor_company_id}) do
    page_visits =
      Enum.map(visited_pages, fn page ->
        analyze_webpage(page)
      end)

    case identify_stage(page_visits) do
      {:ok, stage} ->
        update_lead_with_stage(tenant_id, visitor_company_id, stage)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp determine_lead_stage({:error, reason}), do: {:error, reason}

  defp identify_stage(page_visits) do
    case StageIdentifier.identify(page_visits) do
      {:ok, stage} -> {:ok, stage}
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_lead_with_stage(tenant_id, visitor_company_id, stage) do
    case Leads.get_lead_by_company_ref(tenant_id, visitor_company_id) do
      {:ok, lead} ->
        Leads.update_lead(lead, %{stage: stage})

      {:error, :not_found} ->
        Logger.error(
          "Failed to update lead with stage: lead not found for #{tenant_id} and #{visitor_company_id}"
        )

        {:error, :not_found}
    end
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
      {:ok, url, classification, intent}
    else
      {:error, result} -> {:error, result}
    end
  end

  defp process_webpage_content({:error, reason}), do: {:error, reason}

  defp save_analysis({:ok, url, classification, intent}) do
    case Webpages.update_classification_and_intent(url, classification, intent) do
      {:ok, %ScrapedWebpage{} = webpage} ->
        {url, webpage.summary, intent}

      {:error, reason} ->
        Logger.error("Failed to save webpage analysis for #{url}")
        {:error, reason}
    end
  end

  defp save_analysis({:error, reason}), do: {:error, reason}
end
