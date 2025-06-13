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

  @doc """
  Initiates the HubSpot OAuth authorization flow.
  """
  def authorize(conn, _params) do
    {:ok, url} = OAuth.authorize_url(:hubspot)
    redirect(conn, external: url)
  end

  @doc """
  Handles the OAuth callback from HubSpot.
  """
  def callback(conn, %{"code" => code}) do
    case OAuth.get_token(:hubspot, code) do
      {:ok, token} ->
        case create_integration_connection(conn.assigns.current_tenant.id, :hubspot, token) do
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
    case Registry.remove_connection(conn.assigns.current_tenant.id, :hubspot) do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{status: "success", message: "Successfully disconnected from HubSpot"})

      {:error, reason} ->
        Logger.error("Failed to disconnect HubSpot: #{inspect(reason)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: "Failed to disconnect from HubSpot"})
    end
  end

  # Private functions

  defp create_integration_connection(tenant_id, provider, %{access_token: access_token} = token) do
    Registry.register_connection(tenant_id, provider, %{
      access_token: access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: token.token_type
    })
  end
end
