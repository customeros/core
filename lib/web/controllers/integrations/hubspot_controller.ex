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
    redirect_uri = Application.get_env(:core, :hubspot)[:redirect_uri]

    # Check for existing connection
    case Registry.get_connection(tenant_id, :hubspot) do
      {:ok, _connection} ->
        # Connection exists, return error
        conn
        |> put_status(:conflict)
        |> json(%{
          status: "error",
          message: "A HubSpot connection already exists. Please disconnect it first before creating a new one."
        })

      {:error, :not_found} ->
        # No existing connection, proceed with authorization
        {:ok, url} = HubSpotOAuth.authorize_url(tenant_id, redirect_uri)
        Logger.debug("Redirecting to HubSpot authorization URL: #{url}")
        conn
        |> put_status(302)
        |> put_resp_header("location", url)
        |> halt()
    end
  end

  @doc """
  Handles the OAuth callback from HubSpot.
  """
  def callback(conn, %{"code" => code}) do
    tenant_id = conn.assigns.current_user.tenant_id
    redirect_uri = Application.get_env(:core, :hubspot)[:redirect_uri]

    case HubSpotOAuth.exchange_code(code, redirect_uri) do
      {:ok, token} ->
        credentials = %{
          access_token: token.access_token,
          refresh_token: token.refresh_token,
          expires_at: token.expires_at,
          token_type: token.token_type,
          scopes: token.scopes
        }

        case Connections.create_connection(%{
               tenant_id: tenant_id,
               provider: :hubspot,
               status: :active
             } |> Map.merge(credentials)) do
          {:ok, _connection} ->
            conn
            |> put_status(:ok)
            |> json(%{status: "success", message: "Successfully connected to HubSpot"})

          {:error, reason} ->
            Logger.error("Failed to create HubSpot connection: #{inspect(reason)}")
            conn
            |> put_status(:internal_server_error)
            |> json(%{status: "error", message: "Failed to complete HubSpot integration"})
        end

      {:error, reason} ->
        Logger.error("Failed to get HubSpot token: #{inspect(reason)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: "Failed to complete HubSpot integration"})
    end
  end

  def callback(conn, %{"error" => error, "error_description" => description}) do
    Logger.error("HubSpot OAuth error: #{error} - #{description}")
    conn
    |> put_status(:bad_request)
    |> json(%{status: "error", message: "HubSpot authorization failed: #{description}"})
  end

  def callback(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{status: "error", message: "Invalid HubSpot callback"})
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
