defmodule Core.Crm.Leads.NewLeadPipeline do
  @moduledoc """
  Manages the automated processing pipeline for new leads.

  This module coordinates:
  * Lead domain extraction and validation
  * Website crawling and content analysis
  * ICP fit evaluation
  * Account brief generation
  * Error handling and retry logic

  It implements a robust pipeline that processes new leads
  asynchronously, with retry mechanisms and proper error
  handling for each step. The pipeline ensures leads are
  properly analyzed and categorized based on their fit
  and potential value.
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Core.Crm.Leads
  alias Core.Researcher.BriefWriter
  alias Core.Researcher.IcpFitEvaluator
  alias Core.Utils.Tracing

  def start(lead_id, tenant_id) do
    OpenTelemetry.Tracer.with_span "new_lead_pipeline.start" do
      OpenTelemetry.Tracer.set_attributes([
        {"lead.id", lead_id},
        {"lead.tenant_id", tenant_id}
      ])

      span_ctx = OpenTelemetry.Ctx.get_current()

      Task.Supervisor.start_child(
        Core.TaskSupervisor,
        fn ->
          OpenTelemetry.Ctx.attach(span_ctx)

          case new_lead_pipeline(lead_id, tenant_id) do
            :not_a_company ->
              OpenTelemetry.Tracer.set_attributes([
                {"result", :not_a_company}
              ])

              Logger.info("Lead_id #{lead_id} is not a company")

            {:ok, _} ->
              Logger.info(
                "Successfully completed new lead pipeline for #{lead_id}"
              )

            {:error, reason} ->
              Tracing.error(reason)

              Logger.error("New Lead Pipeline failed for #{lead_id}",
                tenant_id: tenant_id,
                lead_id: lead_id,
                reason: reason
              )
          end
        end
      )
    end
  end

  def new_lead_pipeline(lead_id, tenant_id) do
    OpenTelemetry.Tracer.with_span "new_lead_pipeline.new_lead_pipeline" do
      Logger.metadata(module: __MODULE__, function: :new_lead_pipeline)

      Logger.info("Starting new lead pipeline",
        lead_id: lead_id,
        tenant_id: tenant_id
      )

      Leads.get_domain_for_lead_company(tenant_id, lead_id)
      |> analyze_icp_fit()
      |> brief_writer()
    end
  end

  defp analyze_icp_fit({:ok, domain, %Leads.Lead{} = lead}) do
    OpenTelemetry.Tracer.with_span "new_lead_pipeline.analyze_icp_fit" do
      OpenTelemetry.Tracer.set_attributes([
        {"lead.id", lead.id},
        {"lead.tenant_id", lead.tenant_id},
        {"domain", domain}
      ])

      Logger.metadata(module: __MODULE__, function: :analyze_icp_fit_with_retry)

      Logger.info("Analyzing ICP fit",
        lead_id: lead.id,
        domain: domain,
        tenant_id: lead.tenant_id
      )

      case IcpFitEvaluator.evaluate(domain, lead) do
        {:ok, :not_a_fit} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", :not_a_fit}
          ])

          {:ok, :not_a_fit}

        {:ok, fit} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", fit}
          ])

          {:ok, fit, domain, lead}

        {:error, reason} ->
          Logger.error("ICP evaluation failed",
            tenant_id: lead.tenant_id,
            lead_id: lead.id,
            domain: domain,
            reason: reason
          )

          Tracing.error(reason)

          {:error, reason}
      end
    end
  end

  defp analyze_icp_fit(:not_a_company), do: :not_a_company

  defp analyze_icp_fit({:error, reason}),
    do: {:error, reason}

  defp brief_writer({:ok, fit, domain, %Leads.Lead{} = lead}) do
    OpenTelemetry.Tracer.with_span "new_lead_pipeline.brief_writer" do
      OpenTelemetry.Tracer.set_attributes([
        {"lead.id", lead.id},
        {"lead.tenant_id", lead.tenant_id},
        {"domain", domain},
        {"icp_fit", fit}
      ])

      Logger.metadata(module: __MODULE__, function: :brief_writer)

      Logger.info("Writing Account Brief",
        lead_id: lead.id,
        domain: domain,
        tenant_id: lead.tenant_id,
        icp_fit: fit
      )

      case BriefWriter.create_brief(lead.tenant_id, lead.id, domain) do
        {:ok, _document} ->
          {:ok, :brief_created}

        {:error, reason} ->
          Tracing.error(reason)

          Logger.error("Account brief creation failed",
            tenant_id: lead.tenant_id,
            lead_id: lead.id,
            domain: domain,
            reason: reason
          )

          {:error, reason}
      end
    end
  end

  defp brief_writer({:ok, :not_a_fit}), do: {:ok, :not_a_fit}
  defp brief_writer(:not_a_company), do: :not_a_company
  defp brief_writer({:error, reason}), do: {:error, reason}
end
