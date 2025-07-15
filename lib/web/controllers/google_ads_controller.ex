defmodule Web.GoogleAdsController do
  @moduledoc """
  Controller for handling Google Ads integration operations.

  This controller manages the OAuth flow and integration management for Google Ads,
  including authorization, callback handling, and disconnection.
  """

  use Web, :controller
  require Logger

  alias Core.Integrations.Connections
  alias Core.Integrations.Registry
  alias Core.Integrations.OAuth.Providers.GoogleAds, as: GoogleAdsOAuth
  alias Core.Utils.Tracing

  @doc """
  Initiates the Google Ads OAuth authorization flow.

  Returns an error if a connection already exists for the tenant.
  """
  def connect(conn, _params) do
    tenant_id = conn.assigns.current_user.tenant_id

    redirect_uri = append_to_base_url("/google-ads/callback")

    # Check for existing connection
    case Registry.get_connection(tenant_id, :google_ads) do
      {:ok, _connection} ->
        conn
        |> put_flash(
          :error,
          "A Google Ads connection already exists. Please disconnect it first before creating a new one."
        )
        |> redirect(to: ~p"/leads")

      {:error, :not_found} ->
        case GoogleAdsOAuth.authorize_url(tenant_id, redirect_uri) do
          {:ok, url} ->
            conn
            |> put_status(302)
            |> put_resp_header("location", url)
            |> send_resp(302, "")
        end
    end
  end

  @doc """
  Handles the OAuth callback from Google Ads.
  """
  def callback(conn, params) do
    tenant_id = conn.assigns.current_user.tenant_id
    redirect_uri = append_to_base_url("/google-ads/callback")

    case params do
      %{"code" => code} ->
        handle_successful_oauth(conn, code, redirect_uri, tenant_id)

      %{"error" => error, "error_description" => description} ->
        Logger.error(
          "Google Ads OAuth error: #{inspect(error)} - #{inspect(description)}"
        )

        conn
        |> put_flash(:error, "Google Ads authorization failed: #{description}")
        |> redirect(to: ~p"/leads")

      _ ->
        Logger.error("Invalid Google Ads callback params: #{inspect(params)}")

        conn
        |> put_flash(:error, "Invalid Google Ads callback")
        |> redirect(to: ~p"/leads")
    end
  end

  defp handle_successful_oauth(conn, code, redirect_uri, tenant_id) do
    with {:ok, token} <- exchange_code_for_token(code, redirect_uri),
         {:ok, connection} <- create_google_ads_connection(token, tenant_id),
         {:ok, customer_id} <- obtain_customer_id(token.access_token),
         {:ok, _updated} <- save_customer_id(connection, customer_id) do
      conn
      |> put_flash(:success, "Successfully connected to Google Ads")
      |> redirect(to: ~p"/leads")
    else
      {:error, error} ->
        case Registry.get_connection(tenant_id, :google_ads) do
          {:ok, connection} -> Connections.delete_connection(connection)
          _ -> :ok
        end

        Tracing.error(error, "Failed to complete Google Ads integration")

        conn
        |> put_flash(
          :error,
          "Failed to complete Google Ads integration: #{error}"
        )
        |> redirect(to: ~p"/leads")
    end
  end

  defp exchange_code_for_token(code, redirect_uri) do
    case GoogleAdsOAuth.exchange_code(code, redirect_uri) do
      {:ok, token} ->
        {:ok, token}

      {:error, reason} ->
        {:error, "Failed to exchange code for token: #{inspect(reason)}"}
    end
  end

  defp obtain_customer_id(access_token) do
    Core.Integrations.OAuth.Providers.GoogleAds.get_customer_id(access_token)
  end

  defp save_customer_id(connection, customer_id) do
    case Connections.update_connection(connection, %{
           external_system_id: customer_id
         }) do
      {:ok, updated_connection} ->
        {:ok, updated_connection}

      {:error, changeset} ->
        Logger.error(
          "Failed to update connection with customer_id: #{inspect(changeset.errors)}"
        )

        {:error, "Failed to update connection with customer ID"}
    end
  end

  defp create_google_ads_connection(token, tenant_id, customer_id \\ nil) do
    Logger.info(
      "Creating Google Ads connection with token: #{inspect(token, pretty: true)}"
    )

    connection_params = %{
      tenant_id: tenant_id,
      provider: :google_ads,
      status: :active,
      external_system_id: customer_id && to_string(customer_id),
      access_token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: token.token_type,
      scopes: Application.get_env(:core, :google_ads)[:scopes] || []
    }

    Logger.info(
      "Connection params: #{inspect(connection_params, pretty: true)}"
    )

    case Connections.create_connection(connection_params) do
      {:ok, connection} ->
        Logger.info(
          "Successfully created Google Ads connection: #{inspect(connection, pretty: true)}"
        )

        {:ok, connection}

      {:error, reason} ->
        Logger.error(
          "Failed to create Google Ads connection: #{inspect(reason)}"
        )

        {:error, "Failed to create Google Ads connection"}
    end
  end

  @doc """
  Disconnects the Google Ads integration.
  """
  def disconnect(conn, _params) do
    tenant_id = conn.assigns.current_user.tenant_id

    case Connections.get_connection(tenant_id, :google_ads) do
      {:ok, connection} ->
        # Revoke the token from Google Ads before deleting the connection
        case Core.Integrations.Providers.GoogleAds.Client.revoke_token(
               connection.access_token
             ) do
          :ok ->
            Logger.info(
              "Successfully revoked Google Ads token for tenant #{tenant_id}"
            )

          {:error, reason} ->
            Logger.error(
              "Failed to revoke Google Ads token for tenant #{tenant_id}: #{inspect(reason)}"
            )
        end

        case Connections.delete_connection(connection) do
          {:ok, _} ->
            conn
            |> put_flash(:success, "Successfully disconnected from Google Ads")
            |> redirect(to: ~p"/leads")

          {:error, reason} ->
            Logger.error(
              "Failed to delete Google Ads connection: #{inspect(reason)}"
            )

            conn
            |> put_flash(:error, "Failed to disconnect from Google Ads")
            |> redirect(to: ~p"/leads")
        end

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "No active Google Ads connection found")
        |> redirect(to: ~p"/leads")
    end
  end

  @doc """
  Lists Google Ads campaigns for testing the connection.
  """
  def list_campaigns(conn, _params) do
    tenant_id = conn.assigns.current_user.tenant_id

    case Connections.get_connection(tenant_id, :google_ads) do
      {:ok, connection} ->
        case Core.Integrations.Providers.GoogleAds.Campaigns.list_campaigns(
               connection
             ) do
          {:ok, campaigns} ->
            json(conn, %{
              success: true,
              campaigns: campaigns
            })

          {:error, reason} ->
            Logger.error(
              "Failed to list Google Ads campaigns: #{inspect(reason)}"
            )

            conn
            |> put_status(500)
            |> json(%{
              success: false,
              error: "Failed to list campaigns: #{inspect(reason)}"
            })
        end

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{
          success: false,
          error: "No active Google Ads connection found"
        })
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
