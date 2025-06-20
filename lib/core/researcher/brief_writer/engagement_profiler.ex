defmodule Core.Researcher.BriefWriter.EngagementProfiler do
  @moduledoc """
  Synthesizes all account engagement to date.
  """

  require Logger
  alias Core.Ai
  alias Core.Crm.Leads
  alias Core.Auth.Tenants
  alias Core.Crm.Companies
  alias Core.Utils.TaskAwaiter
  alias Core.WebTracker.Events
  alias Core.Utils.UrlFormatter
  alias Core.Researcher.Webpages
  alias Core.WebTracker.Sessions
  alias Core.Utils.MarkdownValidator
  import Core.Utils.Pipeline

  @max_tokens 1024
  @model :claude_sonnet
  @model_temperature 0.3
  @timeout 60_000

  @err_no_description {:error, "no company description"}
  @err_unexpected_result {:error, "unexpected_result"}

  def engagement_summary(tenant_id, lead_id) do
    Logger.info("Building engagement summary for #{tenant_id} and #{lead_id}")

    with {:ok, company, lead_stage} <-
           get_company_and_stage(tenant_id, lead_id),
         {:ok, sessions} <- get_all_sessions_for_lead(tenant_id, company.id),
         {:ok, visitor_count} <- get_unique_visitor_count(sessions),
         {:ok, page_visits} <- get_page_visits(sessions),
         {:ok, company_description} <-
           get_company_description(company.primary_domain),
         {:ok, engagement_summary} <-
           generate_engagement_summary(
             company.name,
             company_description,
             visitor_count,
             lead_stage,
             page_visits
           ),
         {:ok, clean_output} <-
           MarkdownValidator.validate_and_clean(engagement_summary) do
      {:ok, clean_output}
    else
      {:error, reason} ->
        Logger.error("Failed to generate engagement summary: #{reason}",
          tenant_id: tenant_id,
          lead_id: lead_id
        )

        {:error, reason}
    end
  end

  defp get_company_and_stage(tenant_id, lead_id) do
    Logger.info(
      "Getting company and stage info for #{tenant_id} and #{lead_id}"
    )

    with {:ok, lead} <- Leads.get_by_id(tenant_id, lead_id),
         {:ok, company} <- Companies.get_by_id(lead.ref_id) do
      {:ok, company, lead.stage}
    else
      {:error, reason} ->
        Logger.error("Failed to get company and stage: #{reason}",
          tenant_id: tenant_id,
          lead_id: lead_id
        )

        {:error, reason}
    end
  end

  defp get_unique_visitor_count(sessions) do
    Logger.info("Getting unique visitor count")

    case get_unique_visitors(sessions) do
      [] ->
        Logger.error("Unexpected result: Unique visitor count is 0")
        @err_unexpected_result

      visitors ->
        {:ok, length(visitors)}
    end
  end

  defp get_page_visits(sessions) do
    Logger.info("Getting page visits info")

    case get_page_visit_history(sessions) do
      {:ok, page_visits} ->
        webpages =
          page_visits
          |> Enum.map(&get_webpage_or_log_error/1)
          |> Enum.reject(&is_nil/1)

        {:ok, webpages}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_webpage_or_log_error(visit) do
    case Webpages.get_by_url(visit) do
      {:ok, webpage} ->
        webpage

      {:error, reason} ->
        Logger.error("Failed to get page visits: #{reason}")
        nil
    end
  end

  defp get_page_visit_history(sessions) do
    sessions
    |> ok(&get_all_events_from_sessions/1)
    |> ok(&get_unique_page_visits/1)
  end

  defp get_all_events_from_sessions(sessions) do
    events =
      sessions
      |> Enum.flat_map(fn item ->
        case Events.get_visited_pages(item.id) do
          {:error, :not_found} ->
            []

          {:ok, results} ->
            results
        end
      end)

    {:ok, events}
  end

  defp get_unique_page_visits(events) do
    unique_visits =
      events
      |> Enum.map(fn item ->
        url =
          case item do
            url when is_binary(url) -> url
            %{href: href} -> href
            _ -> nil
          end

        case url && UrlFormatter.get_base_url(url) do
          {:ok, base_url} -> base_url
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    {:ok, unique_visits}
  end

  defp get_unique_visitors(sessions) do
    sessions
    |> Enum.flat_map(fn item ->
      if item.ip, do: [item.ip], else: []
    end)
    |> Enum.uniq()
  end

  defp get_all_sessions_for_lead(tenant_id, company_id) do
    with {:ok, tenant} <- Tenants.get_tenant_by_id(tenant_id),
         {:ok, sessions} <-
           Sessions.get_all_closed_sessions_by_tenant_and_company(
             tenant.name,
             company_id
           ) do
      {:ok, sessions}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_company_description(domain) do
    with {:ok, url} <- UrlFormatter.to_https(domain),
         {:ok, homepage} <- Webpages.get_by_url(url),
         true <- byte_size(homepage.summary) > 0 do
      {:ok, homepage.summary}
    else
      false -> @err_no_description
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_engagement_summary(
         company_name,
         company_description,
         visitor_count,
         lead_stage,
         page_visits
       ) do
    {system_prompt, prompt} =
      build_prompts(
        company_name,
        company_description,
        visitor_count,
        lead_stage,
        page_visits
      )

    request =
      Ai.Request.new(prompt,
        model: @model,
        system_prompt: system_prompt,
        max_tokens: @max_tokens,
        temperature: @model_temperature
      )

    task = Ai.ask_supervised(request)
    TaskAwaiter.await(task, @timeout)
  end

  defp build_prompts(
         company_name,
         company_description,
         visitor_count,
         lead_stage,
         page_visits
       ) do
    system_prompt = """
          I will provide you with a company description, a list of all the pages they've visited on my website, and a summary of the contents of each page.  Your job is to help me produce an engagement summary report that contains everything a SDR needs to start a relevant, high value conversation with this company that helps them solve a real business problem they are likely to have.

          I will also give you where this company is in the buyer's journey and how many people from the company have engaged.  Please produce a brief with only these specific sections:
          - Most interested in
          - Most relevant value proposition
          - Engagement depth

          IMPORTANT:  Your brief must be returned in valid markdown format only!

          What Makes a Great Account Brief: Quality Standards
        A great brief tells a story that makes the prospect feel like you already understand their business better than 99% of vendors who contact them.
    """

    # Format the page visits into a readable string
    formatted_page_visits = format_page_visits(page_visits)

    prompt = """
          Company Name: #{company_name}
          Company Overview: #{company_description}
          Count of Unique People who have engaged: #{visitor_count}
          Current Buyer's Journey Stage: #{lead_stage}

          Page Visit Information: #{formatted_page_visits}
    """

    {system_prompt, prompt}
  end

  defp format_page_visits(page_visits) do
    page_visits
    |> Enum.map(fn webpage ->
      """
      URL: #{webpage.url}
      Page Topic: #{webpage.primary_topic}
      Summary: #{webpage.summary}
      Value Proposition: #{webpage.value_proposition}
      Key Pain Points: #{Enum.join(webpage.key_pain_points, ", ")}
      """
    end)
    |> Enum.join("\n---\n")
  end
end
