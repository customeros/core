defmodule Core.WebTracker.SessionAnalyzer do
  @moduledoc """
  Web session post processing and analysis to determine where the visitor is in their buying journey.
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Core.Utils.UrlFormatter
  alias Core.Researcher.Webpages.Intent
  alias Core.Crm.Leads
  alias Core.Crm.Leads.Lead
  alias Core.Researcher.Webpages.ScrapedWebpage
  alias Core.WebTracker.StageIdentifier
  alias Core.Researcher.Webpages
  alias Core.WebTracker.Events
  alias Core.Researcher.Scraper
  alias Core.WebTracker.Sessions
  alias Core.Auth.Tenants
  alias Core.Utils.TaskAwaiter
  alias Core.Crm.Companies
  alias Core.Researcher.BriefWriter
  alias Core.Crm.Documents

  @analysis_timeout 60 * 1000

  @err_unable_to_get_page_visits {:error, "unable to process page visits"}

  def start(session_id) do
    Task.Supervisor.start_child(
      Core.TaskSupervisor,
      fn ->
        analyze_session(session_id)
      end
    )
  end

  def analyze_session(session_id) do
    OpenTelemetry.Tracer.with_span "session_analyzer.analyze_session" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.session.id", session_id}
      ])

      session_id
      |> session_details()
      |> determine_lead_stage()
      |> create_brief()
    end
  end

  defp session_details(session_id) do
    Logger.metadata(module: __MODULE__, function: :session_details)

    Logger.info("Aggregating web session details for #{session_id}",
      session_id: session_id
    )

    with {:ok, session} <- Sessions.get_session_by_id(session_id),
         {:ok, :proceed} <- ok_to_run(session.tenant, session.company_id),
         {:ok, all_company_sessions} <-
           Sessions.get_all_closed_sessions_by_tenant_and_company(
             session.tenant,
             session.company_id
           ),
         {:ok, visited_pages} <- get_visited_pages(all_company_sessions),
         {:ok, tenant} <- Tenants.get_tenant_by_name(session.tenant) do
      {:ok, tenant.id, visited_pages, session.company_id}
    else
      {:stop, reason} ->
        {:stop, reason}

      {:error, reason} ->
        Logger.error("Analyze session error: #{inspect(reason)}")

        {:error, reason}
    end
  end

  defp ok_to_run(_tenant, nil), do: {:stop, :no_company_id}

  defp ok_to_run(tenant, company_id) when not is_nil(company_id) do
    with {:ok, tenant} <- Tenants.get_tenant_by_name(tenant),
         {:ok, lead} when not is_nil(company_id) <-
           Leads.get_by_ref_id(tenant.id, company_id) do
      cond do
        lead.stage == :ready_to_buy -> {:stop, :already_ready_to_buy}
        lead.stage == :customer -> {:stop, :already_customer}
        lead.icp_fit == :not_a_fit -> {:stop, :not_icp_fit}
        lead.icp_fit == :unknown -> {:stop, :unknown_icp_fit}
        true -> {:ok, :proceed}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_visited_pages(all_sessions) do
    Logger.info("Getting all page visits")

    try do
      visited_pages =
        all_sessions
        |> Enum.flat_map(fn session ->
          case Events.get_visited_pages(session.id) do
            {:ok, visited_pages} -> visited_pages
            {:error, _} -> []
          end
        end)

      {:ok, visited_pages}
    rescue
      error ->
        Logger.error("Error getting visited pages: #{inspect(error)}")
        @err_unable_to_get_page_visits
    end
  end

  defp determine_lead_stage({:ok, tenant_id, visited_pages, visitor_company_id}) do
    page_visits =
      visited_pages
      |> Enum.map(&analyze_webpage/1)
      |> Enum.reject(&match?({:error, _}, &1))

    case page_visits do
      [] ->
        Logger.error("There are no webpages to analyze from websession")
        {:error, :no_analyzable_pages}

      successful_visits ->
        case identify_stage(successful_visits) do
          {:ok, stage} ->
            update_lead_with_stage(tenant_id, visitor_company_id, stage)

          {:error, reason} ->
            Logger.error(
              "Unable to determine lead stage for #{tenant_id} and #{visitor_company_id}: #{reason}"
            )

            {:error, reason}
        end
    end
  end

  defp determine_lead_stage({:error, reason}), do: {:error, reason}
  defp determine_lead_stage({:stop, reason}), do: {:stop, reason}

  defp identify_stage(page_visits) do
    case StageIdentifier.identify(page_visits) do
      {:ok, stage} ->
        {:ok, stage}

      {:error, reason} ->
        Logger.error("Failed to identify stage from page_visits")
        {:error, reason}
    end
  end

  defp update_lead_with_stage(tenant_id, visitor_company_id, stage) do
    case Leads.get_lead_by_company_ref(tenant_id, visitor_company_id) do
      {:ok, lead} ->
        case Leads.update_lead(lead, %{stage: stage}) do
          {:ok, _} -> {:ok, tenant_id, visitor_company_id}
          {:error, reason} -> {:error, reason}
        end

      {:error, :not_found} ->
        Logger.error(
          "Failed to update lead with stage: lead not found for #{tenant_id} and #{visitor_company_id}"
        )

        {:error, :not_found}
    end
  end

  defp analyze_webpage(url) do
    url
    |> UrlFormatter.get_base_url()
    |> UrlFormatter.to_https()
    |> get_webpage_content()
    |> process_webpage_content()
    |> save_analysis()
  end

  defp get_webpage_content({:ok, url}) do
    case Scraper.scrape_webpage(url) do
      {:ok, _} ->
        {:ok, url}

      {:error, reason} ->
        Logger.error("Failed to get website content for #{url}")
        {:error, reason}
    end
  end

  defp process_webpage_content({:ok, url}) do
    case Webpages.get_by_url(url) do
      {:ok, content_record} ->
        if needs_processing?(content_record) do
          case analyze_content(url, content_record.content) do
            {:ok, intent} ->
              {:ok, url, intent}

            {:error, reason} ->
              Logger.error(
                "Failed to process #{url} for intent: #{inspect(reason)}"
              )

              {:error, reason}
          end
        else
          return_existing(url, content_record)
        end

      {:error, reason} ->
        Logger.error("Failed to process #{url} for intent: #{inspect(reason)}")
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

    case TaskAwaiter.await(task, @analysis_timeout) do
      {:ok, intent} -> {:ok, intent}
      {:error, reason} -> {:error, reason}
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

  defp create_brief({:error, reason}), do: {:error, reason}
  defp create_brief({:stop, reason}), do: {:stop, reason}

  defp create_brief({:ok, tenant_id, visitor_company_id}) do
    with {:ok, lead} <-
           Leads.get_lead_by_company_ref(tenant_id, visitor_company_id),
         true <- lead_applicable_for_brief_creation?(lead),
         {:ok, domain} <- get_company_domain(lead.ref_id),
         :ok <- create_brief_document_if_missing(lead, domain) do
      :ok
    else
      false ->
        Logger.info("Skipping brief creation - lead not applicable")
        :ok

      {:error, reason} ->
        Logger.error("Brief creation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp lead_applicable_for_brief_creation?(%Lead{} = lead) do
    lead.icp_fit in [:strong, :moderate] and lead.stage != :customer
  end

  defp get_company_domain(company_id) do
    case Companies.get_by_id(company_id) do
      {:ok, company} ->
        Logger.info("Company found: #{company.primary_domain}")
        {:ok, company.primary_domain}

      {:error, reason} ->
        Logger.error("Company not found: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_brief_document_if_missing(%Lead{} = lead, domain) do
    Logger.info("Checking if Account Brief document exists for lead #{lead.id}")

    case Documents.get_documents_by_ref_id(lead.id) do
      [] ->
        Logger.info("No existing documents found for lead #{lead.id}")
        create_brief_document(lead, domain)

      documents ->
        case Enum.find(documents, fn doc -> doc.name == "Account Brief" end) do
          nil ->
            Logger.info(
              "Found #{length(documents)} existing document(s) for lead #{lead.id}, but no Account Brief"
            )

            Logger.info("Creating Account Brief as it doesn't exist")
            create_brief_document(lead, domain)

          _account_brief ->
            Logger.info(
              "Found #{length(documents)} existing document(s) for lead #{lead.id}, including Account Brief"
            )

            Logger.info(
              "Skipping brief creation as Account Brief already exists"
            )

            :ok
        end
    end
  end

  defp create_brief_document(%Lead{} = lead, domain) do
    case BriefWriter.create_brief(lead.tenant_id, lead.id, domain) do
      {:ok, _document} ->
        Logger.info("Document created for lead #{lead.id}")
        :ok

      {:error, :closed_sessions_not_found} ->
        Logger.warning("Closed sessions not available, skipping brief creation")
        {:error, :closed_sessions_not_found}

      {:error, reason} ->
        Logger.error("Account brief creation failed: #{inspect(reason)}",
          lead_id: lead.id,
          url: domain,
          tenant_id: lead.tenant_id
        )

        {:error, reason}
    end
  end
end
