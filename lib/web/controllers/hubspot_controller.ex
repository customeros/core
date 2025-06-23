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

    redirect_uri = append_to_base_url("/hubspot/callback")

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
    redirect_uri = append_to_base_url("/hubspot/callback")

    case params do
      %{"code" => code} ->
        handle_successful_oauth(conn, code, redirect_uri, tenant_id)

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

  defp handle_successful_oauth(conn, code, redirect_uri, tenant_id) do
    with {:ok, token} <- exchange_code_for_token(code, redirect_uri),
         {:ok, hub_id} <- get_hubspot_portal_id(token),
         {:ok, _connection} <-
           create_hubspot_connection(token, hub_id, tenant_id) do
      conn
      |> put_flash(:success, "Successfully connected to HubSpot")
      |> redirect(to: ~p"/leads")
    else
      {:error, reason} ->
        Logger.error(
          "Failed to complete HubSpot integration: #{inspect(reason)}"
        )

        conn
        |> put_flash(:error, "Failed to complete HubSpot integration")
        |> redirect(to: ~p"/leads")
    end
  end

  defp exchange_code_for_token(code, redirect_uri) do
    case HubSpotOAuth.exchange_code(code, redirect_uri) do
      {:ok, {:ok, %Core.Integrations.OAuth.Token{} = token}} ->
        {:ok, token}

      {:ok, {:error, reason}} ->
        Logger.error("Failed to exchange code for token: #{inspect(reason)}")
        {:error, :token_exchange_failed}

      {:error, reason} ->
        Logger.error("Failed to exchange code for token: #{inspect(reason)}")
        {:error, :token_exchange_failed}
    end
  end

  defp get_hubspot_portal_id(token) do
    case HubSpotOAuth.get_portal_info(token.access_token) do
      {:ok, hub_id} ->
        Logger.info("Got HubSpot portal ID: #{hub_id}")
        {:ok, hub_id}

      {:error, reason} ->
        Logger.error("Failed to get HubSpot portal ID: #{inspect(reason)}")
        {:error, :portal_info_failed}
    end
  end

  defp create_hubspot_connection(token, hub_id, tenant_id) do
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

        {:ok, connection}

      {:error, reason} ->
        Logger.error("Failed to create HubSpot connection: #{inspect(reason)}")
        {:error, :connection_creation_failed}
    end
  end

  @doc """
  Disconnects the HubSpot integration.
  """
  def disconnect(conn, _params) do
    tenant_id = conn.assigns.current_user.tenant_id

    case Connections.get_connection(tenant_id, :hubspot) do
      {:ok, connection} ->
        # Revoke the token from HubSpot before deleting the connection
        case Core.Integrations.Providers.HubSpot.Client.revoke_token(
               connection.access_token
             ) do
          :ok ->
            Logger.info(
              "Successfully revoked HubSpot token for tenant #{tenant_id}"
            )

          {:error, reason} ->
            Logger.error(
              "Failed to revoke HubSpot token for tenant #{tenant_id}: #{inspect(reason)}"
            )
        end

        case Connections.delete_connection(connection) do
          {:ok, _} ->
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

  # Private functions

  defp append_to_base_url(path) when is_binary(path) do
    scheme = Application.get_env(:core, :url)[:scheme] || "http"
    host = Application.get_env(:core, :url)[:host] || "localhost:4000"

    # Ensure path starts with /
    path = if String.starts_with?(path, "/"), do: path, else: "/#{path}"

    "#{scheme}://#{host}#{path}"
  end
end
