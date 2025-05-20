defmodule Web.WebTrackerController do
  use Web, :controller
  require Logger

  plug Web.Plugs.ValidateWebTrackerHeaders when action in [:create]

  def create(conn, params) do
    # Log validated headers
    # Logger.info("""
    # WebTracker Event:
    # Origin: #{conn.assigns.origin}
    # Referer: #{conn.assigns.referer}
    # User-Agent: #{conn.assigns.user_agent}
    # Body: #{inspect(params, pretty: true)}
    # """)

    # For now, just return accepted
    conn
    |> put_status(:accepted)
    |> json(%{accepted: true})
  end
end
