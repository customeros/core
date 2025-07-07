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
  require Logger
  require OpenTelemetry.Tracer

  alias Core.Utils.Tracing
  alias Core.Crm.Documents
  alias Core.Researcher.BriefWriter.AccountResearcher
  alias Core.Researcher.BriefWriter.EngagementProfiler

  def create_brief(tenant_id, lead_id, lead_domain) do
    OpenTelemetry.Tracer.with_span "brief_writer.create_brief" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.tenant.id", tenant_id},
        {"param.lead.id", lead_id},
        {"param.domain", lead_domain}
      ])

      with {:ok, account_overview} <-
             AccountResearcher.account_overview(tenant_id, lead_domain),
           {:ok, engagement_summary} <-
             EngagementProfiler.engagement_summary(tenant_id, lead_id) do
        build_and_save_document(
          tenant_id,
          lead_id,
          account_overview,
          engagement_summary
        )
      else
        {:error, :closed_sessions_not_found} ->
          Tracing.warning(
            :closed_sessions_not_found,
            "Closed sessions not available, skipping brief creation"
          )

          {:error, :closed_sessions_not_found}

        {:error, reason} ->
          Tracing.error(reason, "Account Brief failed",
            tenant_id: tenant_id,
            lead_id: lead_id,
            company_domain: lead_domain
          )

          {:error, reason}
      end
    end
  end

  defp build_and_save_document(
         tenant_id,
         lead_id,
         account_overview,
         engagement_summary
       ) do
    document = build_document(account_overview, engagement_summary)
    save_document(tenant_id, lead_id, document)
  end

  defp build_document(account_overview, engagement_summary) do
    account_overview <> "\n" <> engagement_summary
  end

  defp save_document(tenant_id, lead_id, brief) do
    doc =
      Documents.Document.new_account_brief(
        tenant_id,
        lead_id,
        brief
      )

    Documents.create_document(doc)
  end
end
