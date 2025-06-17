defmodule Web.HubspotController do
  @moduledoc """
  Controller for handling HubSpot integration operations.

  This controller manages the OAuth flow and integration management for HubSpot,
  including authorization, callback handling, and disconnection.
  """

  use Web, :controller
  require Logger

  alias Core.Integrations.Connections
  alias Core.Integrations.Registry
  alias Core.Integrations.OAuth.Providers.HubSpot, as: HubSpotOAuth

  @doc """
  Initiates the HubSpot OAuth authorization flow.

  Returns an error if a connection already exists for the tenant.
  """
  def connect(conn, _params) do
    tenant_id = conn.assigns.current_user.tenant_id

    base_url = "#{conn.scheme}://#{get_req_header(conn, "host")}"
    redirect_uri = "#{base_url}/hubspot/callback"

    # Check for existing connection
    case Registry.get_connection(tenant_id, :hubspot) do
      {:ok, _connection} ->
        conn
        |> put_flash(
          :error,
          "A HubSpot connection already exists. Please disconnect it first before creating a new one."
        )
        |> redirect(to: ~p"/leads")

      {:error, :not_found} ->
        case HubSpotOAuth.authorize_url(tenant_id, redirect_uri) do
          {:ok, url} ->
            conn
            |> put_status(302)
            |> put_resp_header("location", url)
            |> send_resp(302, "")
        end
    end
  end

  @doc """
  Handles the OAuth callback from HubSpot.
  """
  def callback(conn, params) do
    tenant_id = conn.assigns.current_user.tenant_id

    base_url = "#{conn.scheme}://#{get_req_header(conn, "host")}"
    redirect_uri = "#{base_url}/hubspot/callback"

    case params do
      %{"code" => code} ->
        case HubSpotOAuth.exchange_code(code, redirect_uri) do
          {:ok, {:ok, %Core.Integrations.OAuth.Token{} = token}} ->
            # Get HubSpot portal ID from the token info
            case HubSpotOAuth.get_portal_info(token.access_token) do
              {:ok, hub_id} ->
                Logger.info("Got HubSpot portal ID: #{hub_id}")

                # Extract token fields into a map for connection creation
                connection_params = %{
                  tenant_id: tenant_id,
                  provider: :hubspot,
                  status: :active,
                  external_system_id: to_string(hub_id),
                  access_token: token.access_token,
                  refresh_token: token.refresh_token,
                  expires_at: token.expires_at,
                  token_type: token.token_type,
                  scopes: Application.get_env(:core, :hubspot)[:scopes] || []
                }

                case Connections.create_connection(connection_params) do
                  {:ok, connection} ->
                    Logger.info(
                      "Successfully created HubSpot connection: #{inspect(connection, pretty: true)}"
                    )
                    conn
                    |> put_flash(:success, "Successfully connected to HubSpot")
                    |> redirect(to: ~p"/leads")

                  {:error, reason} ->
                    Logger.error(
                      "Failed to create HubSpot connection: #{inspect(reason)}"
                    )

                    conn
                    |> put_flash(
                      :error,
                      "Failed to complete HubSpot integration"
                    )
                    |> redirect(to: ~p"/leads")
                end

              {:error, reason} ->
                Logger.error(
                  "Failed to get HubSpot portal ID: #{inspect(reason)}"
                )

                conn
                |> put_flash(:error, "Failed to complete HubSpot integration")
                |> redirect(to: ~p"/leads")
            end

          {:ok, {:error, reason}} ->
            Logger.error(
              "Failed to exchange code for token: #{inspect(reason)}"
            )

            conn
            |> put_flash(:error, "Failed to complete HubSpot integration")
            |> redirect(to: ~p"/leads")

          {:error, reason} ->
            Logger.error(
              "Failed to exchange code for token: #{inspect(reason)}"
            )

            conn
            |> put_flash(:error, "Failed to complete HubSpot integration")
            |> redirect(to: ~p"/leads")
        end

      %{"error" => error, "error_description" => description} ->
        Logger.error("HubSpot OAuth error: #{error} - #{description}")

        conn
        |> put_flash(:error, "HubSpot authorization failed: #{description}")
        |> redirect(to: ~p"/leads")

      _ ->
        Logger.error("Invalid HubSpot callback params: #{inspect(params)}")

        conn
        |> put_flash(:error, "Invalid HubSpot callback")
        |> redirect(to: ~p"/leads")
    end
  end

  @doc """
  Disconnects the HubSpot integration.
  """
  def disconnect(conn, _params) do
    tenant_id = conn.assigns.current_user.tenant_id

    case Connections.get_connection(tenant_id, :hubspot) do
      {:ok, connection} ->
        case Connections.delete_connection(connection) do
          {:ok, _} ->
            # TODO: Uninstall app from HubSpot
            conn
            |> put_flash(:success, "Successfully disconnected from HubSpot")
            |> redirect(to: ~p"/leads")

          {:error, reason} ->
            Logger.error(
              "Failed to delete HubSpot connection: #{inspect(reason)}"
            )

            conn
            |> put_flash(:error, "Failed to disconnect from HubSpot")
            |> redirect(to: ~p"/leads")
        end

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "No active HubSpot connection found")
        |> redirect(to: ~p"/leads")
    end
  end

  @doc """
  Handles incoming HubSpot webhooks (e.g., company update events).
  """
  def webhook(conn, %{"tenant_id" => tenant_id} = _params) do
    with {:ok, connection} <- Registry.get_connection(tenant_id, :hubspot),
         {:ok, webhook_mod} <- Registry.get_webhook(:hubspot),
         {:ok, body, _conn} <- Plug.Conn.read_body(conn),
         {:ok, events} <- Jason.decode(body) do
      # For each event, if it's a company update, fetch and log company details
      Enum.each(events, fn event ->
        if event["subscriptionType"] == "company.propertyChange" do
          case webhook_mod.process_event(connection, event) do
            {:ok, %{processed: true}} ->
              Logger.info("Processed HubSpot company update event: #{inspect(event)}")
            {:error, reason} ->
              Logger.error("Failed to process HubSpot company update event: #{inspect(reason)}")
          end
        end
      end)
      send_resp(conn, 200, "ok")
    else
      {:error, :not_found} ->
        Logger.error("No HubSpot connection found for tenant #{tenant_id}")
        send_resp(conn, 404, "No connection found")
      {:error, reason} ->
        Logger.error("Failed to process HubSpot webhook: #{inspect(reason)}")
        send_resp(conn, 400, "Webhook error")
    end
  end
end
