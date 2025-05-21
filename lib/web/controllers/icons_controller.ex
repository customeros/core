defmodule Web.IconsController do
  use Web, :controller

  def index(conn, _params) do
    conn
    |> put_resp_content_type("image/svg+xml")
    |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("expires", "0")
    |> send_file(200, "priv/static/images/icons.svg")
  end
end 