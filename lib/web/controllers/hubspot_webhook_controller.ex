defmodule Web.Controllers.HubspotWebhookController do
  use Web, :controller
  require Logger

  alias Core.Integrations.Connections

  def webhook(conn, _params) do
    with {:ok, body, _conn} <- Plug.Conn.read_body(conn),
         {:ok, events} <- Jason.decode(body) do
      config = Application.get_env(:core, :hubspot)
      app_id = config[:app_id]

      Enum.each(events, fn event ->
        # a. Validate appId
        if Map.get(event, "appId") != app_id do
          Logger.error("[HubSpot Webhook] Unknown appId: #{inspect(event["appId"])}. Ignoring event.")
        else
          # b. Find connection by provider and portalId
          portal_id = to_string(event["portalId"])
          case Connections.get_connection_by_provider_and_external_id(:hubspot, portal_id) do
            {:ok, connection} ->
              Logger.debug("[HubSpot Webhook] Found connection for portalId #{portal_id} (tenant_id: #{connection.tenant_id})")
              # c. TODO: Handle company by objectId (event["objectId"])
              :ok
            {:error, :not_found} ->
              Logger.error("[HubSpot Webhook] No connection found for portalId #{portal_id}. Ignoring event.")
          end
        end
      end)
      send_resp(conn, 200, "ok")
    else
      {:error, reason} ->
        Logger.error("[HubSpot Webhook] Failed to parse webhook body: #{inspect(reason)}")
        send_resp(conn, 200, "ok")
    end
  end
end
