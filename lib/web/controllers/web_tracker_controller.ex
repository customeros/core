defmodule Web.WebTrackerController do
  use Web, :controller
  require Logger

  alias Core.WebTracker.OriginValidator

  plug Web.Plugs.ValidateWebTrackerHeaders when action in [:create]

  def create(conn, _params) do
    if OriginValidator.should_ignore_origin?(conn.assigns.origin) do
      conn
      |> put_status(:forbidden)
      |> json(%{error: "forbidden", details: "origin explicitly ignored"})
    else
      # For now, just return accepted
      conn
      |> put_status(:accepted)
      |> json(%{accepted: true})
    end
  end
end
