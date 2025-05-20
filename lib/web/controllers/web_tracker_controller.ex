defmodule Web.WebTrackerController do
  use Web, :controller
  require Logger

  alias Core.WebTracker.OriginValidator
  alias Core.WebTracker.OriginTenantMapper

  plug Web.Plugs.ValidateWebTrackerHeaders when action in [:create]

  def create(conn, _params) do
    origin = conn.assigns.origin

    cond do
      OriginValidator.should_ignore_origin?(origin) ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden", details: "origin explicitly ignored"})

      not OriginTenantMapper.whitelisted?(origin) ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden", details: "origin not configured"})

      true ->
        {:ok, tenant} = OriginTenantMapper.get_tenant_for_origin(origin)

        # Store tenant in conn.assigns for further processing
        conn = assign(conn, :tenant, tenant)

        # For now, just return accepted with tenant info
        conn
        |> put_status(:accepted)
        |> json(%{accepted: true, tenant: tenant})
    end
  end
end
