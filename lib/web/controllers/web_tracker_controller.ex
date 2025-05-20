defmodule Web.WebTrackerController do
  use Web, :controller
  require Logger

  def create(conn, params) do
    # Log headers for debugging
    headers = Enum.map(conn.req_headers, fn {key, value} -> "#{key}: #{value}" end)
    Logger.info("WebTracker Event Headers: #{inspect(headers, pretty: true)}")

    # Log body for debugging
    Logger.info("WebTracker Event Body: #{inspect(params, pretty: true)}")

    # For now, just return accepted
    conn
    |> put_status(:accepted)
    |> json(%{accepted: true})
  end
end
