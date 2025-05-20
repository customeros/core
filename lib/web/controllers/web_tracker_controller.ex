defmodule Web.WebTrackerController do
  use Web, :controller
  require Logger

  alias Core.WebTracker
  alias Core.WebTracker.OriginValidator
  alias Core.WebTracker.OriginTenantMapper

  plug Web.Plugs.ValidateWebTrackerHeaders when action in [:create]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    origin = conn.assigns.origin
    user_agent = conn.assigns.user_agent
    referer = conn.assigns.referer
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    visitor_id = Map.get(params, "visitor_id")

    with :ok <- validate_origin(origin),
         {:ok, tenant} <- OriginTenantMapper.get_tenant_for_origin(origin),
         :ok <- WebTracker.check_bot(user_agent),
         :ok <- WebTracker.check_suspicious(referer) do

      # Process the new event
      case WebTracker.process_new_event(%{
        tenant: tenant,
        visitor_id: visitor_id,
        origin: origin,
        ip: ip
      }) do
        {:ok, _result} ->
          conn
          |> put_status(:accepted)
          |> json(%{accepted: true})

        {:error, :forbidden, _message} ->
          conn
          |> put_status(:forbidden)
          |> json(%{error: "forbidden", details: "request blocked"})

        {:error, _status, _message} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "internal_server_error", details: "something went wrong"})
      end
    else
      {:error, :bot} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden", details: "bot detected"})

      {:error, :suspicious} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden", details: "suspicious referrer"})

      {:error, :origin_ignored} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden", details: "origin explicitly ignored"})

      {:error, :origin_not_configured} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden", details: "origin not configured"})
    end
  end

  @spec validate_origin(String.t()) :: :ok | {:error, atom()}
  defp validate_origin(origin) do
    cond do
      OriginValidator.should_ignore_origin?(origin) ->
        {:error, :origin_ignored}
      not OriginTenantMapper.whitelisted?(origin) ->
        {:error, :origin_not_configured}
      true ->
        :ok
    end
  end
end
