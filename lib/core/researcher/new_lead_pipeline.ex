defmodule Core.Researcher.NewLeadPipeline do
  require Logger
  alias Core.Crm.Leads
  alias Core.Crm.Companies
  alias Core.Researcher.Crawler
  alias Core.Researcher.BriefWriter
  alias Core.Researcher.IcpFitEvaluator

  @max_retry 2
  @default_timeout 45 * 1000
  @crawl_timeout 5 * 60 * 1000

  def new_lead_pipeline_start(lead_id, tenant_id) do
    Task.Supervisor.start_child(
      Core.TaskSupervisor,
      fn ->
        new_lead_pipeline(lead_id, tenant_id)
      end
    )
  end

  def new_lead_pipeline(lead_id, tenant_id) do
    case get_lead_domain(lead_id, tenant_id) do
      {:ok, domain, lead} ->
        analyze_lead(lead, domain)

      :stop ->
        nil

      {:error, step, reason} ->
        handle_pipeline_error(lead_id, step, reason)
    end
  end

  defp analyze_lead(lead, domain) do
    with :ok <- crawl_website_with_retry(domain),
         :ok <- analyze_icp_fit_with_retry(domain, lead),
         :ok <-
           generate_account_brief_with_retry(lead, domain) do
      :ok
    else
      :stop ->
        nil

      {:error, step, reason} ->
        handle_pipeline_error(lead, step, reason)
    end
  end

  defp generate_account_brief_with_retry(lead, domain, attempts \\ 0) do
    task = BriefWriter.start(lead.tenant_id, lead.id, domain)

    with {:ok, _response} <- await_task(task, @default_timeout) do
      :ok
    else
      {:error, _reason} when attempts < @max_retry ->
        :timer.sleep(:timer.seconds(attempts + 1))
        generate_account_brief_with_retry(lead, domain, attempts + 1)

      {:error, reason} ->
        {:error, "account brief", reason}
    end
  end

  defp analyze_icp_fit_with_retry(domain, lead, attempts \\ 0) do
    task = IcpFitEvaluator.evaluate_start(domain, lead)

    case await_task(task, @default_timeout) do
      {:ok, :not_a_fit} ->
        :stop

      {:ok, _icp} ->
        :ok

      {:error, _reason} when attempts < @max_retry ->
        :timer.sleep(:timer.seconds(attempts + 1))
        analyze_icp_fit_with_retry(domain, lead, attempts + 1)

      {:error, reason} ->
        {:error, "icp fit", reason}
    end
  end

  defp crawl_website_with_retry(domain, attempts \\ 0) do
    task = Crawler.crawl_supervised(domain)

    with {:ok, _response} <- await_task(task, @crawl_timeout) do
      :ok
    else
      {:error, _reason} when attempts < @max_retry ->
        :timer.sleep(:timer.seconds(attempts + 1))
        crawl_website_with_retry(domain, attempts + 1)

      {:error, reason} ->
        {:error, "crawl website", reason}
    end
  end

  defp await_task(task, timeout) do
    case Task.yield(task, timeout) do
      {:ok, {:ok, response}} -> {:ok, response}
      {:ok, {:error, reason}} -> {:error, reason}
      {:exit, reason} -> {:error, reason}
      nil -> {:error, :timeout}
    end
  end

  defp get_lead_domain(tenant_id, lead_id) do
    with {:ok, lead} <- Leads.get_by_id(tenant_id, lead_id),
         true <- lead.type == :company,
         {:ok, company} <-
           Companies.get_by_id(lead.ref_id) do
      {:ok, company.primary_domain, lead}
    else
      false -> :stop
      {:error, :not_found} -> :stop
      {:error, reason} -> {:error, "Lookup lead", reason}
    end
  end

  defp handle_pipeline_error(lead_id, step, reason) do
    err = "Failed #{step}: #{inspect(reason)}"
    Logger.error("Pipeline failed for #{lead_id} - #{err}")

    Leads.update_lead(%Leads.Lead{id: lead_id}, %{error_message: err})
  end
end
