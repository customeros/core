
Application.ensure_all_started(:core)

defmodule HourlyStats do
  def run(tenant_id) do
    start_time = ~U[2025-06-10 00:00:00Z]
    current_time = DateTime.utc_now()
    
    hours_diff = DateTime.diff(current_time, start_time, :hour)
    
    IO.puts("Generating stats for #{hours_diff + 1} hours...")
    
    # Generate stats for each hour
    0..hours_diff
    |> Enum.each(fn hour_offset ->
      hour_start = DateTime.add(start_time, hour_offset, :hour)
      
      IO.puts("Processing hour: #{DateTime.to_iso8601(hour_start)}")
      
      case Core.Analytics.Builder.build_hourly_aggregate_stats(tenant_id, hour_start) do
        {:ok, result} ->
          IO.puts("  ✓ Success: #{inspect(result)}")
        {:error, error} ->
          IO.puts("  ✗ Error: #{inspect(error)}")
      end
    end)
    
    IO.puts("Completed processing #{hours_diff + 1} hours of data")
  end
end

HourlyStats.run("tenant_4048efgi9ya6kzxt")
