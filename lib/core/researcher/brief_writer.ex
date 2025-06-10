defmodule Core.Researcher.BriefWriter do
  @moduledoc """
  Generates account briefs for leads using AI analysis.

  This module manages:
  * Account brief generation for leads
  * AI prompt construction and execution
  * Integration with ICP profiles
  * Document creation and storage
  * Asynchronous processing

  It coordinates the generation of comprehensive account briefs
  by analyzing business pages, leveraging ICP profiles, and using
  AI to create detailed briefs that are stored as documents in
  the system. The module handles both supervised (async) and
  direct brief creation workflows.
  """

  alias Core.Ai
  alias Core.Crm.Leads
  alias Core.Crm.Documents
  alias Core.Researcher.Webpages
  alias Core.Researcher.IcpProfiles
  alias Core.Utils.MarkdownValidator
  alias Core.Researcher.BriefWriter.PromptBuilder

  @timeout 60 * 1000

  def create_brief(tenant_id, lead_id, lead_domain) do
    with {:ok, icp} <- IcpProfiles.get_by_tenant_id(tenant_id),
         {:ok, lead} <- Leads.get_by_id(tenant_id, lead_id),
         {:ok, pages} <-
           Webpages.get_business_pages_by_domain(lead_domain, limit: 8),
         request <- build_request(lead_domain, icp, pages),
         {:ok, brief} <- generate_brief(request),
         {:ok, validated_brief} <- MarkdownValidator.validate_and_clean(brief) do
      save_document(lead, validated_brief)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_request(domain, icp, buisenss_pages) do
    {system_prompt, prompt} =
      PromptBuilder.build_prompts(domain, buisenss_pages, icp)

    PromptBuilder.build_request(system_prompt, prompt)
  end

  defp generate_brief(request) do
    task = Ai.ask_supervised(request)

    case Task.yield(task, @timeout) do
      {:ok, {:ok, answer}} ->
        {:ok, answer}

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:exit, reason} ->
        {:error, reason}

      nil ->
        Task.shutdown(task)
        {:error, :timeout}
    end
  end

  defp save_document(lead, brief) do
    doc =
      Documents.Document.new_account_brief(
        lead.tenant_id,
        lead.id,
        brief
      )

    Documents.create_document(doc)
  end
end
