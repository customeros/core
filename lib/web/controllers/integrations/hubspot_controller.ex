defmodule Web.Controllers.Integrations.HubspotController do
  @moduledoc """
  Controller for handling HubSpot integration operations.

  This controller manages the OAuth flow and integration management for HubSpot,
  including authorization, callback handling, and disconnection.
  """

  use Web, :controller
  require Logger

  alias Core.Integrations.{Connection, Connections, Registry}
  alias Core.Integrations.OAuth.Providers.HubSpot, as: HubSpotOAuth

  @doc """
  Initiates the HubSpot OAuth authorization flow.

  Returns an error if a connection already exists for the tenant.
  """
  def authorize(conn, _params) do
    tenant_id = conn.assigns.current_user.tenant_id
    Logger.debug("=== HubSpot Controller Debug ===")
    Logger.debug("1. Request details:")
    Logger.debug("   - tenant_id: #{tenant_id}")
    Logger.debug("   - host: #{conn.host}")
    Logger.debug("   - scheme: #{conn.scheme}")
    Logger.debug("   - port: #{conn.port}")
    Logger.debug("   - headers: #{inspect(conn.req_headers)}")

    config = Application.get_env(:core, :hubspot)
    redirect_uri = config[:redirect_uri]
    Logger.debug("2. Redirect URI from config:")
    Logger.debug("   - raw: #{inspect(redirect_uri)}")
    Logger.debug("   - parsed: #{inspect(URI.parse(redirect_uri))}")

    # Check for existing connection
    case Registry.get_connection(tenant_id, :hubspot) do
      {:ok, connection} ->
        Logger.debug("3. Existing connection found:")
        Logger.debug("   #{inspect(connection, pretty: true)}")
        conn
        |> put_status(:conflict)
        |> json(%{
          status: "error",
          message: "A HubSpot connection already exists. Please disconnect it first before creating a new one."
        })

      {:error, :not_found} ->
        Logger.debug("3. No existing connection, proceeding with authorization")
        case HubSpotOAuth.authorize_url(tenant_id, redirect_uri) do
          {:ok, url} ->
            Logger.debug("4. Generated OAuth URL:")
            Logger.debug("   #{url}")
            Logger.debug("5. Sending redirect response:")
            Logger.debug("   - status: 302")
            Logger.debug("   - location: #{url}")
            Logger.debug("=== End HubSpot Controller Debug ===")

            conn
            |> put_status(302)
            |> put_resp_header("location", url)
            |> send_resp(302, "")

          {:error, reason} ->
            Logger.error("Failed to generate HubSpot OAuth URL: #{inspect(reason)}")
            conn
            |> put_status(:internal_server_error)
            |> json(%{
              status: "error",
              message: "Failed to start HubSpot authorization"
            })
        end
    end
  end

  @doc """
  Handles the OAuth callback from HubSpot.
  """
  def callback(conn, params) do
    tenant_id = conn.assigns.current_user.tenant_id
    Logger.debug("Received HubSpot callback for tenant #{tenant_id}")
    Logger.debug("Callback params: #{inspect(params)}")
    Logger.debug("Request headers: #{inspect(conn.req_headers)}")
    Logger.debug("Request host: #{conn.host}")
    Logger.debug("Request scheme: #{conn.scheme}")

    config = Application.get_env(:core, :hubspot)
    redirect_uri = config[:redirect_uri]

    case params do
      %{"code" => code} ->
        Logger.debug("Received authorization code, exchanging for token")

        case HubSpotOAuth.exchange_code(code, redirect_uri) do
          {:ok, {:ok, %Core.Integrations.OAuth.Token{} = token}} ->
            Logger.debug("Successfully exchanged code for token in callback: #{inspect(token, pretty: true)}")

            # Extract token fields into a map for connection creation
            connection_params = %{
              tenant_id: tenant_id,
              provider: :hubspot,
              status: :active,
              access_token: token.access_token,
              refresh_token: token.refresh_token,
              expires_at: token.expires_at,
              token_type: token.token_type,
              scopes: token.scopes
            }

            case Connections.create_connection(connection_params) do
              {:ok, connection} ->
                Logger.debug("Successfully created HubSpot connection: #{inspect(connection, pretty: true)}")
                conn
                |> put_status(:ok)
                |> json(%{status: "success", message: "Successfully connected to HubSpot"})

              {:error, reason} ->
                Logger.error("Failed to create HubSpot connection: #{inspect(reason)}")
                conn
                |> put_status(:internal_server_error)
                |> json(%{status: "error", message: "Failed to complete HubSpot integration"})
            end

          {:ok, {:error, reason}} ->
            Logger.error("Failed to exchange code for token: #{inspect(reason)}")
            conn
            |> put_status(:internal_server_error)
            |> json(%{status: "error", message: "Failed to complete HubSpot integration"})

          {:error, reason} ->
            Logger.error("Failed to exchange code for token: #{inspect(reason)}")
            conn
            |> put_status(:internal_server_error)
            |> json(%{status: "error", message: "Failed to complete HubSpot integration"})
        end

      %{"error" => error, "error_description" => description} ->
        Logger.error("HubSpot OAuth error: #{error} - #{description}")
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: "HubSpot authorization failed: #{description}"})

      _ ->
        Logger.error("Invalid HubSpot callback params: #{inspect(params)}")
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: "Invalid HubSpot callback"})
    end
  end

  @doc """
  Disconnects the HubSpot integration.
  """
  def disconnect(conn, _params) do
    tenant_id = conn.assigns.current_user.tenant_id

    case Registry.remove_connection(tenant_id, :hubspot) do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{status: "success", message: "Successfully disconnected from HubSpot"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "No active HubSpot connection found"})

      {:error, reason} ->
        Logger.error("Failed to disconnect HubSpot: #{inspect(reason)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: "Failed to disconnect from HubSpot"})
    end
  end
end
