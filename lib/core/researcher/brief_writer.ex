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

  alias Core.Crm.Documents
  alias Core.Researcher.BriefWriter.AccountResearcher
  # alias Core.Researcher.BriefWriter.EngagementProfiler

  def create_brief(tenant_id, lead_id, lead_domain) do
    case AccountResearcher.account_overview(tenant_id, lead_domain) do
      {:ok, account_overview} ->
        # {:ok, engagement_summary} <-
        #   EngagementProfiler.engagement_summary(tenant_id, lead_id) do
        save_document(lead_id, account_overview)

      {:error, reason} ->
        {:error, reason}
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
