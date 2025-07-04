defmodule Core.Crm.Leads.NewLeadPipelineRerun do
  alias Core.Crm.Leads
  alias Core.Crm.Leads.NewLeadPipeline

  @max_concurrency 5

  def rerun_not_a_fits(tenant_id) do
    with {:ok, leads} <-
           Leads.get_icp_not_a_fits_without_disqual_reason(tenant_id) do
      leads
      |> Task.async_stream(
        fn lead -> process_lead_safely(lead, tenant_id) end,
        max_concurrency: @max_concurrency,
        timeout: :timer.minutes(5),
        on_timeout: :kill_task
      )
      |> Stream.with_index()
      |> Enum.reduce({[], []}, fn
        {{:ok, {:success, result}}, index}, {successes, failures} ->
          IO.puts("Completed record #{index + 1}/#{length(leads)}")
          {[result | successes], failures}

        {{:ok, {:error, reason}}, index}, {successes, failures} ->
          IO.puts("Failed record #{index + 1}: #{inspect(reason)}")
          {successes, [reason | failures]}

        {{:exit, reason}, index}, {successes, failures} ->
          IO.puts("Task crashed #{index + 1}: #{inspect(reason)}")
          {successes, [reason | failures]}
      end)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_lead_safely(lead, tenant_id) do
    try do
      case NewLeadPipeline.new_lead_pipeline(lead.id, tenant_id) do
        {:ok, result} -> {:success, result}
        {:error, reason} -> {:error, reason}
        other -> {:error, {:unexpected_result, other}}
      end
    rescue
      exception -> {:error, {:exception, Exception.message(exception)}}
    catch
      :exit, reason -> {:error, {:exit, reason}}
      :throw, reason -> {:error, {:throw, reason}}
    end
  end
end
