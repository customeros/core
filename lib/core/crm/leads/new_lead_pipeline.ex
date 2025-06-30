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

  def start(lead_id, tenant_id, callback \\ nil, opts \\ []) do
    OpenTelemetry.Tracer.with_span "new_lead_pipeline.start" do
      OpenTelemetry.Tracer.set_attributes([
        {"lead.id", lead_id},
        {"tenant.id", tenant_id}
      ])

      span_ctx = OpenTelemetry.Ctx.get_current()

      Task.Supervisor.start_child(
        Core.TaskSupervisor,
        fn ->
          OpenTelemetry.Ctx.attach(span_ctx)

          case new_lead_pipeline(lead_id, tenant_id, callback, opts) do
            :ok ->
              Logger.info(
                "Successfully completed new lead pipeline for #{lead_id}"
              )

            {:error, :not_a_company} ->
              OpenTelemetry.Tracer.set_attributes([
                {"result", :not_a_company}
              ])

              Logger.info("Lead_id #{lead_id} is not a company")

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

  defp applicable_for_icp_fit?(lead) do
    lead.icp_fit not in [:moderate, :strong] and lead.stage != :customer
  end

  def new_lead_pipeline(lead_id, tenant_id, callback \\ nil, opts \\ []) do
    OpenTelemetry.Tracer.with_span "new_lead_pipeline.new_lead_pipeline" do
      OpenTelemetry.Tracer.set_attributes([
        {"lead.id", lead_id},
        {"tenant.id", tenant_id}
      ])

      Logger.metadata(module: __MODULE__, function: :new_lead_pipeline)

      Logger.info("Starting new lead pipeline",
        lead_id: lead_id,
        tenant_id: tenant_id
      )

      with {:ok, lead} <- Leads.get_by_id(tenant_id, lead_id),
           true <- applicable_for_icp_fit?(lead),
           {:ok, domain} <-
             Leads.get_domain_for_lead_company(tenant_id, lead_id),
           {:ok, fit} <- analyze_icp_fit(domain, lead, opts),
           :ok <- execute_callback_if_provided(callback, fit),
           :ok <- brief_writer(fit, domain, lead) do
        :ok
      else
        false ->
          Logger.info("Skipping ICP fit analysis - lead not applicable")
          :ok

        {:error, reason} ->
          Tracing.error(reason, "New Lead Pipeline failed for #{lead_id}",
            lead_id: lead_id
          )

          {:error, reason}
      end
    end
  end

  defp analyze_icp_fit(domain, %Leads.Lead{} = lead, opts)
       when is_binary(domain) do
    OpenTelemetry.Tracer.with_span "new_lead_pipeline.analyze_icp_fit" do
      OpenTelemetry.Tracer.set_attributes([
        {"lead.id", lead.id},
        {"tenant.id", lead.tenant_id},
        {"domain", domain}
      ])

      Logger.metadata(module: __MODULE__, function: :analyze_icp_fit)

      Logger.info("Analyzing ICP fit",
        lead_id: lead.id,
        url: domain,
        tenant_id: lead.tenant_id
      )

      case IcpFitEvaluator.evaluate(domain, lead, opts) do
        {:ok, :not_a_fit} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", :not_a_fit}
          ])

          {:ok, :not_a_fit}

        {:ok, fit} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", fit}
          ])

          {:ok, lead}

        {:error, reason} ->
          Tracing.error(
            reason,
            "ICP evaluation failed",
            lead_id: lead.id,
            tenant_id: lead.tenant_id,
            url: domain
          )

          {:error, reason}
      end
    end
  end

  defp execute_callback_if_provided(callback, fit)
       when is_function(callback) do
    Logger.info("Executing callback before brief creation")

    callback.(fit)
  end

  defp execute_callback_if_provided(_, _), do: :ok

  defp brief_writer(:not_a_fit, _domain, _lead), do: :ok

  defp brief_writer(fit, domain, %Leads.Lead{} = lead) do
    OpenTelemetry.Tracer.with_span "new_lead_pipeline.brief_writer" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.lead.id", lead.id},
        {"param.tenant.id", lead.tenant_id},
        {"param.domain", domain},
        {"param.icp_fit", fit}
      ])

      Logger.metadata(module: __MODULE__, function: :brief_writer)

      Logger.info("Writing Account Brief",
        lead_id: lead.id,
        url: domain,
        tenant_id: lead.tenant_id,
        icp_fit: fit
      )

      case BriefWriter.create_brief(lead.tenant_id, lead.id, domain) do
        {:ok, _document} ->
          :ok

        {:error, :closed_sessions_not_found} ->
          Tracing.warning(
            :not_found,
            "Sessions data not ready for brief creation"
          )

          {:error, :closed_sessions_not_found}

        {:error, reason} ->
          Tracing.error(reason, "Account brief creation failed",
            lead_id: lead.id,
            url: domain,
            tenant_id: lead.tenant_id
          )

          {:error, reason}
      end
    end
  end
end
