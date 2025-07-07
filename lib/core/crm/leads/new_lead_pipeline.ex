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
  alias Core.Utils.Tracing
  alias Core.Crm.Leads.Lead
  alias Core.Researcher.IcpFitEvaluator

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

          new_lead_pipeline(lead_id, tenant_id, callback, opts)
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
           :ok <- execute_callback_if_provided(callback, fit) do
        :ok
      else
        false ->
          Logger.info("Skipping ICP fit analysis - lead not applicable")
          :ok

        {:error, reason} ->
          Tracing.warning(reason, "New Lead Pipeline failed for #{lead_id}",
            lead_id: lead_id
          )

          handle_error(lead_id, tenant_id, reason)
      end
    end
  end

  defp handle_error(lead_id, tenant_id, reason) do
    case Leads.get_by_id(tenant_id, lead_id) do
      {:ok, %Lead{} = lead} ->
        Leads.update_lead(lead, %{
          icp_fit: :unknown,
          error_message: to_string(reason)
        })

      {:error, :not_found} ->
        Tracing.error("lead_not_found", "Failed to update lead",
          lead_id: lead_id
        )

        {:error, :lead_not_found}
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

          {:ok, fit}

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
end
