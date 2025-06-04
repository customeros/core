defmodule Core.WebTracker.SessionAnalyzer do
  @moduledoc """
  Web session post processing and analysis to determine where the visitor is in their buying journey.
  """

  require Logger
  alias Core.Researcher.Webpages.Intent
  alias Core.Crm.Leads
  alias Core.Researcher.Webpages.ScrapedWebpage
  alias Core.WebTracker.StageIdentifier
  alias Core.Researcher.Webpages
  alias Core.WebTracker.Events
  alias Core.Researcher.Scraper
  alias Core.WebTracker.Sessions
  alias Core.Auth.Tenants

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
         {:ok, visited_pages} <- Events.get_visited_pages(session_id),
         {:ok, tenant} <- Tenants.get_tenant_by_name(session.tenant) do
      {:ok, tenant.id, visited_pages, session.company_id}
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
      {:ok, _content} -> {:ok, url}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_webpage_content({:ok, url}) do
    case Webpages.get_by_url(url) do
      {:ok, content_record} ->
        if needs_processing?(content_record) do
          case analyze_content(url, content_record.content) do
            {:ok, intent} -> {:ok, url, intent}
            {:error, reason} -> {:error, reason}
          end
        else
          return_existing(url, content_record)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_webpage_content({:error, reason}), do: {:error, reason}

  defp return_existing(url, content_record) do
    intent = %Intent{
      problem_recognition: content_record.problem_recognition_score,
      solution_research: content_record.solution_research_score,
      evaluation: content_record.evaluation_score,
      purchase_readiness: content_record.purchase_readiness_score
    }

    {:already_processed, url, content_record.summary, intent}
  end

  defp needs_processing?(content_record) do
    content_record.problem_recognition_score == nil ||
      content_record.solution_research_score == nil ||
      content_record.evaluation_score == nil ||
      content_record.purchase_readiness_score == nil
  end

  defp analyze_content(url, content) do
    task = Webpages.IntentProfiler.profile_intent_supervised(url, content)
    results = Task.yield(task, @analysis_timeout)

    case results do
      {:ok, {:ok, intent}} -> {:ok, intent}
      {:ok, {:error, reason}} -> {:error, reason}
      {:exit, reason} -> {:error, reason}
      nil -> {:error, :timeout}
    end
  end

  defp save_analysis({:ok, url, intent}) do
    case Webpages.update_intent(url, intent) do
      {:ok, %ScrapedWebpage{} = webpage} ->
        {url, webpage.summary, intent}

      {:error, reason} ->
        Logger.error("Failed to save webpage analysis for #{url}")
        {:error, reason}
    end
  end

  defp save_analysis({:already_processed, url, summary, intent}),
    do: {url, summary, intent}

  defp save_analysis({:error, reason}), do: {:error, reason}
end
