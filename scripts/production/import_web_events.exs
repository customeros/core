Application.ensure_all_started(:core)

defmodule WebEventImporter do
  
  def build_request(row, tenant) do
    %{
      id: row["id"],
      tenant: tenant,
      ip: row["ip"],
      visitor_id: row["visitor_id"],
      event_type: row["event_type"],
      event_data: row["event_data"],
      timestamp: parse_timestamp(row["timestamp"]),
      href: row["href"],
      origin: row["origin"],
      search: row["search"],
      hostname: row["hostname"],
      pathname: row["pathname"],
      referrer: row["referrer"],
      user_agent: row["user_agent"],
      language: row["language"],
      cookies_enabled: parse_boolean(row["cookies_enabled"]),
      screen_resolution: row["screen_resolution"]
    }
  end

  def run(path, tenant, limit \\ nil) do
    stream = path
    |> File.stream!()
    |> CSV.decode(headers: true)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Stream.map(&elem(&1, 1))
    
    stream = if limit, do: Stream.take(stream, limit), else: stream
    
    stream
    |> Stream.map(&build_request(&1, tenant))
    |> Stream.with_index(1)  # Start counting from 1
    |> Stream.each(fn {event, index} ->
      Core.WebTracker.process_new_event(event)
      IO.puts("Processing record #{index}")
      Process.sleep(500)
    end)
    |> Stream.run()  
  end

  defp parse_timestamp(timestamp_string) when is_binary(timestamp_string) do
    case DateTime.from_iso8601(timestamp_string <> "Z") do
      {:ok, datetime, _} -> datetime
      {:error, _} ->
        # Try parsing without Z
        case NaiveDateTime.from_iso8601(timestamp_string) do
          {:ok, naive_dt} -> DateTime.from_naive!(naive_dt, "Etc/UTC")
          {:error, _} -> DateTime.utc_now() # Fallback
        end
    end
  end

  defp parse_boolean("t"), do: true
  defp parse_boolean("f"), do: false
  defp parse_boolean("true"), do: true
  defp parse_boolean("false"), do: false
  defp parse_boolean(true), do: true
  defp parse_boolean(false), do: false
  defp parse_boolean(_), do: false
end

WebEventImporter.run("../infinity_web_events.csv", "infinityco")
