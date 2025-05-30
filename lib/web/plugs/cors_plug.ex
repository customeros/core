defmodule Web.Plugs.CorsPlug do
  import Plug.Conn

  @allowed_origins [
    "https://customeros.ai",
    "https://*.customeros.ai",
    "https://unreal-world-072818.framer.app"
  ]

  def init(opts), do: opts

  def call(conn, _opts) do
    origin = get_req_header(conn, "origin") |> List.first()

    if origin && origin_allowed?(origin) do
      conn
      |> put_resp_header("access-control-allow-origin", origin)
      |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
      |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, X-Requested-With")
      |> put_resp_header("access-control-allow-credentials", "true")
      |> put_resp_header("access-control-max-age", "86400")
      |> handle_preflight()
    else
      conn
    end
  end

  defp handle_preflight(%{method: "OPTIONS"} = conn) do
    conn
    |> send_resp(200, "")
    |> halt()
  end
  defp handle_preflight(conn), do: conn

  defp origin_allowed?(origin) do
    uri = URI.parse(origin)
    host = uri.host || ""

    Enum.any?(@allowed_origins, fn allowed ->
      case allowed do
        "https://" <> pattern ->
          pattern = String.replace(pattern, "*", ".*")
          String.match?(host, ~r/^#{pattern}$/)
        _ ->
          false
      end
    end)
  end
end
