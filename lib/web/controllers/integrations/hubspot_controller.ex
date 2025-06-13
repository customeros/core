defmodule Web.Controllers.Integrations.HubspotController do
  @moduledoc """
  Controller for handling HubSpot integration operations.

  This controller manages the OAuth flow and integration management for HubSpot,
  including authorization, callback handling, and disconnection.
  """

  use Web, :controller
  require Logger
  alias Core.Integrations.HubSpot.OAuth
  alias Core.Integrations.Registry
  alias Core.Integrations.IntegrationConnections

  @doc """
  Initiates the HubSpot OAuth authorization flow.
  """
  def authorize(conn, _params) do
    dbg("hubspot_controller.authorize ===============")
    {:ok, url} = OAuth.authorize_url(:hubspot)
    redirect(conn, external: url)
  end

  @doc """
  Handles the OAuth callback from HubSpot.
  """
  def callback(conn, %{"code" => code}) do
    dbg("hubspot_controller.callback with code ===============")
    tenant_id = conn.assigns.current_tenant.id

    case OAuth.get_token(:hubspot, code) do
      {:ok, token} ->
        credentials = %{
          access_token: token.access_token,
          refresh_token: token.refresh_token,
          expires_at: token.expires_at,
          token_type: token.token_type
        }

        case Registry.register_connection(tenant_id, :hubspot, credentials) do
          :ok ->
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
    dbg("hubspot_controller.callback with error ===============")
    Logger.error("HubSpot OAuth error: #{error} - #{description}")
    conn
    |> put_status(:bad_request)
    |> json(%{status: "error", message: "HubSpot authorization failed: #{description}"})
  end

  def callback(conn, _params) do
    dbg("hubspot_controller.callback invalid params ===============")
    conn
    |> put_status(:bad_request)
    |> json(%{status: "error", message: "Invalid HubSpot callback"})
  end

  @doc """
  Disconnects the HubSpot integration.
  """
  def disconnect(conn, _params) do
    dbg("hubspot_controller.disconnect ===============")
    tenant_id = conn.assigns.current_tenant.id

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
