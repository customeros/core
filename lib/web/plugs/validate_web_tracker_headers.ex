defmodule Web.Plugs.ValidateWebTrackerHeaders do
  @moduledoc """
  Plug to validate required headers for web tracker events.
  Required headers:
  - Origin
  - Referer
  - User-Agent
  """
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.debug("ValidateWebTrackerHeaders plug running...")

    with {:ok, origin} <- validate_header(conn, "origin"),
         {:ok, referer} <- validate_header(conn, "referer"),
         {:ok, user_agent} <- validate_header(conn, "user-agent") do
      # Store validated headers in assigns for later use
      conn
      |> assign(:origin, origin)
      |> assign(:referer, referer)
      |> assign(:user_agent, user_agent)
    else
      {:error, missing_header} ->
        Logger.debug(
          "ValidateWebTrackerHeaders plug halting due to missing #{missing_header}"
        )

        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.json(%{
          error: "forbidden",
          details: "missing #{missing_header}"
        })
        |> halt()
    end
  end

  defp validate_header(conn, header_name) do
    case get_req_header(conn, header_name) do
      [value] when value != "" ->
        {:ok, value}

      _ ->
        Logger.warning("Missing required header: #{header_name}")
        {:error, header_name}
    end
  end
end
