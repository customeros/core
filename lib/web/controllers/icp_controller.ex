defmodule Web.Controllers.IcpController do
  use Web, :controller
  require OpenTelemetry.Tracer

  def create(conn, params) do
    OpenTelemetry.Tracer.with_span "Icp.create" do
      client_ip = get_client_ip(conn)

      OpenTelemetry.Tracer.set_attributes([
        {"http.method", "POST"},
        {"http.route", "/v1/icp"},
        {"client_ip", client_ip}
      ])

      case Hammer.check_rate("icp_api:#{client_ip}", 60_000, 3) do
        {:allow, _count} ->
          handle_icp_request(conn, params)

        {:deny, _limit} ->
          conn
          |> put_status(:too_many_requests)
          |> json(%{error: "Rate limit exceeded.  Try again later."})
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
