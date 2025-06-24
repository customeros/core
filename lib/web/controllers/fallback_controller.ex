defmodule Web.FallbackController do
  use Web, :controller

  def not_found(conn, _params) do
    redirect(conn, to: "/leads")
  end
end
