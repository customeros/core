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

  alias Core.Crm.Leads
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
           {:ok, lead} <- Leads.get_by_id(tenant_id, lead_id),
           {:ok, fit_status} <- validate_account_overview(account_overview),
           {:ok, _updated_lead} <- maybe_update_lead_fit(lead, fit_status),
           {:ok, engagement_summary} <-
             EngagementProfiler.engagement_summary(tenant_id, lead_id),
           {:ok, document} <-
             build_and_save_document(
               tenant_id,
               lead_id,
               account_overview,
               engagement_summary
             ) do
        {:ok, document}
      else
        :not_a_fit ->
          case Leads.disqualify_lead_by_brief_writer(tenant_id, lead_id) do
            {:ok, _lead} -> {:ok, :not_a_fit}
            {:error, reason} -> {:error, reason}
          end

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

  defp validate_account_overview(account_overview) do
    cond do
      String.contains?(account_overview, "not_a_fit") ->
        :not_a_fit

      String.contains?(account_overview, "Strong Fit") ->
        {:ok, :strong}

      String.contains?(account_overview, "Moderate Fit") ->
        {:ok, :moderate}

      true ->
        {:ok, :no_change}
    end
  end

  defp maybe_update_lead_fit(lead, :no_change), do: {:ok, lead}

  defp maybe_update_lead_fit(lead, new_fit)
       when new_fit in [:strong, :moderate] do
    if lead.icp_fit != new_fit do
      Leads.update_lead_field(lead.id, %{icp_fit: new_fit}, "icp_fit")
    else
      {:ok, lead}
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
