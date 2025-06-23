defmodule Web.HubspotWebhookController do
  use Web, :controller
  require Logger

  alias Core.Integrations.Providers.HubSpot.Webhook

  def webhook(conn, _params) do
    with {:ok, _} <- validate_webhook_signature(conn),
         {:ok, events} <- parse_webhook_body(conn) do
      process_webhook_events(events)
      send_resp(conn, 200, "ok")
    else
      {:error, :invalid_signature} ->
        Logger.error(
          "[HubSpotWebhookController] Webhook validation failed: Signature does not match or missing headers"
        )

        send_resp(conn, 401, "Invalid signature")

      {:error, :invalid_json} ->
        send_resp(conn, 400, "Invalid JSON")
    end
  end

  defp validate_webhook_signature(conn) do
    signature = get_req_header(conn, "x-hubspot-signature-v3") |> List.first()

    timestamp =
      get_req_header(conn, "x-hubspot-request-timestamp") |> List.first()

    config = Application.get_env(:core, :hubspot)
    client_secret = config[:client_secret]
    method = conn.method |> String.upcase()
    request_uri = config[:webhook_uri]
    raw_body = conn.assigns[:raw_body] || ""

    if is_nil(signature) or is_nil(timestamp) or
         not Webhook.verify_signature_v3(
           client_secret,
           signature,
           method,
           request_uri,
           raw_body,
           timestamp
         ) do
      {:error, :invalid_signature}
    else
      {:ok, raw_body}
    end
  end

  defp parse_webhook_body(conn) do
    raw_body = conn.assigns[:raw_body] || ""

    case Jason.decode(raw_body) do
      {:ok, events} when is_list(events) -> {:ok, events}
      {:ok, event} -> {:ok, [event]}
      {:error, _} -> {:error, :invalid_json}
    end
  end

  defp process_webhook_events(events) do
    Enum.each(events, &process_single_event/1)
  end

  defp process_single_event(event) do
    case Webhook.process_event_from_webhook(event) do
      {:ok, _result} ->
        Logger.info(
          "[HubspotWebhookController] Processed event: #{inspect(event)}"
        )

      {:error, reason} ->
        Logger.error(
          "[HubspotWebhookController] Failed to process event: #{inspect(reason)}"
        )
    end
  end
end
