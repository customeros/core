defmodule Web.Plugs.EventsCorsPlug do
  @moduledoc """
  Handles Cross-Origin Resource Sharing (CORS) specifically for the events endpoint.
  This plug allows requests from any domain to track events, while maintaining
  security through other validation mechanisms.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    origin = get_req_header(conn, "origin") |> List.first()

    if origin do
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
end
