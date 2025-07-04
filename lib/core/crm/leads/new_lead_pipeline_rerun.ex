defmodule Core.Crm.Leads.NewLeadPipelineRerun do
  alias Core.Crm.Leads
  alias Core.Crm.Leads.NewLeadPipeline

  @max_concurrency 5

  def rerun_not_a_fits(tenant_id) do
    with {:ok, leads} <-
           Leads.get_icp_not_a_fits_without_disqual_reason(tenant_id) do
      leads
      |> Task.async_stream(
        fn lead -> process_lead(lead, tenant_id) end,
        max_concurrency: @max_concurrency,
        timeout: :timer.minutes(5),
        on_timeout: :kill_task
      )
      |> Stream.with_index()
      |> Enum.reduce({[], []}, fn
        {{:ok, result}, index}, {successes, failures} ->
          IO.puts("Completed record #{index + 1}/#{length(leads)}")
          {[result | successes], failures}

        {{:exit, reason}, index}, {successes, failures} ->
          IO.puts("Failed record #{index + 1}: #{inspect(leads)}")
          {successes, [index | failures]}
      end)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def process_lead(lead, tenant_id) do
    NewLeadPipeline.start(lead.id, tenant_id)
  end
end
