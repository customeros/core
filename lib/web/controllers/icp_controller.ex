defmodule Web.IcpController do
  use Web, :controller
  require OpenTelemetry.Tracer

  require Logger
  alias Core.Utils.Media.Images
  alias Core.Utils.PrimaryDomainFinder
  alias Core.Crm.Companies
  alias Core.Researcher.IcpBuilder

  @rate_limit_table :icp_rate_limit
  @max_requests 3
  # 1 minute
  @window_ms 60_000

  def options(conn, _params) do
    origin = get_req_header(conn, "origin") |> List.first()

    conn
    |> put_resp_header("access-control-allow-origin", origin)
    |> put_resp_header(
      "access-control-allow-methods",
      "GET, POST, PUT, PATCH, DELETE, OPTIONS"
    )
    |> put_resp_header(
      "access-control-allow-headers",
      "Content-Type, Authorization, X-Requested-With, Accept, Origin, sec-ch-ua, sec-ch-ua-mobile, sec-ch-ua-platform, sec-fetch-dest, sec-fetch-mode, sec-fetch-site"
    )
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
    domain
    |> PrimaryDomainFinder.get_primary_domain()
    |> get_company()
    |> process_response(conn)
  end

  defp handle_icp_request(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Required parameters not set"})
  end

  defp get_company({:error, reason}), do: {:error, reason}

  defp get_company({:ok, primary_domain}) do
    Companies.get_or_create_by_domain(primary_domain)
  end

  defp process_response({:error, reason}, conn) do
    Logger.info("Returning error: #{reason}")
    return_error({:error, reason}, conn)
  end

  defp process_response({:ok, company}, conn) do
    Logger.info("building ICP...")

    case IcpBuilder.build_icp_fast(company.primary_domain) do
      {:error, reason} -> return_error({:error, reason}, conn)
      {:ok, profile} -> respond(company.id, profile, conn)
    end
  end

  defp respond(company_id, profile, conn) do
    Logger.info("Responding...")

    case Companies.get_by_id(company_id) do
      {:ok, company} ->
        response = %{
          company_name: company.name,
          logo: Images.get_cdn_url(company.icon_key),
          domain: company.primary_domain,
          profile: profile.profile,
          qualifying_attributes: profile.qualifying_attributes
        }

        conn
        |> put_status(:ok)
        |> json(response)

      {:error, :not_found} ->
        Logger.error("Company not found: #{company_id}")

        conn
        |> put_status(:not_found)
        |> json(%{error: "Company not found"})
    end
  end

  defp return_error({:error, reason}, conn) do
    Logger.error("Failed to handle ICP request: #{inspect(reason)}")

    conn
    |> put_status(:internal_server_error)
    |> json(%{error: "Cannot process request at this time."})
  end

  defp check_rate_limit(client_ip) do
    ensure_table_exists()
    now = System.system_time(:millisecond)
    key = "icp_api:#{client_ip}"

    cleanup_old_entries(key, now)

    current_count = get_request_count(key, now)

    if current_count < @max_requests do
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
