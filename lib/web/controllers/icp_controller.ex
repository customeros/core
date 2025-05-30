defmodule Web.IcpController do
  use Web, :controller
  require OpenTelemetry.Tracer

  @rate_limit_table :icp_rate_limit
  @max_requests 3
  # 1 minute
  @window_ms 60_000

  def options(conn, _params) do
    origin = get_req_header(conn, "origin") |> List.first()

    conn
    |> put_resp_header("access-control-allow-origin", origin)
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, X-Requested-With, Accept, Origin, sec-ch-ua, sec-ch-ua-mobile, sec-ch-ua-platform, sec-fetch-dest, sec-fetch-mode, sec-fetch-site")
    |> put_resp_header("access-control-allow-credentials", "true")
    |> put_resp_header("access-control-max-age", "86400")
    |> put_resp_content_type("application/json")
    |> send_resp(200, "{}")
  end

  def create(conn, params) do
    OpenTelemetry.Tracer.with_span "Icp.create" do
      client_ip = get_client_ip(conn)

      OpenTelemetry.Tracer.set_attributes([
        {"http.method", "POST"},
        {"http.route", "/v1/icp"},
        {"client_ip", client_ip}
      ])

      case check_rate_limit(client_ip) do
        :ok ->
          handle_icp_request(conn, params)

        :rate_limited ->
          conn
          |> put_status(:too_many_requests)
          |> json(%{error: "Rate limit exceeded. Try again later."})
      end
    end
  end

  defp handle_icp_request(conn, %{"domain" => domain}) do
    case Core.Researcher.IcpBuilder.build_icp(domain) do
      {:ok, icp} ->
        conn
        |> put_status(:ok)
        |> json(icp)

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Cannot process request at this time."})
    end
  end

  defp handle_icp_request(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Required parameters not set"})
  end

  defp check_rate_limit(client_ip) do
    ensure_table_exists()
    now = System.system_time(:millisecond)
    key = "icp_api:#{client_ip}"

    # Clean up old entries first
    cleanup_old_entries(key, now)

    # Get current request count
    current_count = get_request_count(key, now)

    if current_count < @max_requests do
      # Record this request
      :ets.insert(@rate_limit_table, {key, now})
      :ok
    else
      :rate_limited
    end
  end

  defp ensure_table_exists do
    case :ets.whereis(@rate_limit_table) do
      :undefined ->
        :ets.new(@rate_limit_table, [:public, :named_table, :bag])

      _ ->
        :ok
    end
  end

  defp cleanup_old_entries(key, now) do
    cutoff_time = now - @window_ms

    # Get all entries for this key
    entries = :ets.lookup(@rate_limit_table, key)

    # Remove old entries
    Enum.each(entries, fn {^key, timestamp} ->
      if timestamp < cutoff_time do
        :ets.delete_object(@rate_limit_table, {key, timestamp})
      end
    end)
  end

  defp get_request_count(key, now) do
    cutoff_time = now - @window_ms

    entries = :ets.lookup(@rate_limit_table, key)

    # Count entries within the time window
    Enum.count(entries, fn {^key, timestamp} ->
      timestamp >= cutoff_time
    end)
  end

  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        # Take first IP from comma-separated list
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        case get_req_header(conn, "x-real-ip") do
          [real_ip | _] -> String.trim(real_ip)
          [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
        end
    end
  end
end
