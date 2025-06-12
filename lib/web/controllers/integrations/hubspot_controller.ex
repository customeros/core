defmodule Web.Controllers.Integrations.HubspotController do
  use Web, :controller
  require Logger
  alias Core.Integrations.HubSpot.OAuth
  alias Core.Integrations.Registry

  @doc """
  Redirects to HubSpot OAuth authorization page.
  """
  def authorize(conn, _params) do
    tenant_id = conn.assigns.current_tenant.id

    case OAuth.authorize_url(:hubspot) do
      {:ok, url} ->
        # Store tenant_id in session for callback verification
        conn
        |> put_session(:hubspot_auth_tenant_id, tenant_id)
        |> redirect(external: url)

      {:error, reason} ->
        Logger.error("Failed to generate HubSpot authorization URL: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Failed to connect to HubSpot. Please try again.")
        |> redirect(to: ~p"/integrations")
    end
  end

  @doc """
  Handles the OAuth callback from HubSpot.
  """
  def callback(conn, %{"code" => code}) do
    # Get tenant_id from session
    tenant_id = get_session(conn, :hubspot_auth_tenant_id)

    if is_nil(tenant_id) do
      conn
      |> put_flash(:error, "Invalid authentication session. Please try again.")
      |> redirect(to: ~p"/integrations")
    else
      case OAuth.get_token(:hubspot, code) do
        {:ok, token} ->
          # Store the token in the registry
          Registry.register_connection(tenant_id, :hubspot, token)

          # Store integration connection in database
          create_integration_connection(tenant_id, :hubspot, token)

          conn
          |> delete_session(:hubspot_auth_tenant_id)
          |> put_flash(:info, "HubSpot integration connected successfully!")
          |> redirect(to: ~p"/integrations")

        {:error, reason} ->
          Logger.error("Failed to get HubSpot token: #{inspect(reason)}")

          conn
          |> delete_session(:hubspot_auth_tenant_id)
          |> put_flash(:error, "Failed to connect HubSpot. Please try again.")
          |> redirect(to: ~p"/integrations")
      end
    end
  end

  @doc """
  Handles the OAuth callback error from HubSpot.
  """
  def callback(conn, %{"error" => error}) do
    Logger.error("HubSpot OAuth error: #{inspect(error)}")

    conn
    |> delete_session(:hubspot_auth_tenant_id)
    |> put_flash(:error, "HubSpot authorization failed: #{error}")
    |> redirect(to: ~p"/integrations")
  end

  @doc """
  Handles webhook events from HubSpot.
  """
  def webhook(conn, params) do
    # Extract tenant ID from the webhook URL
    # This assumes you've structured your webhook URLs to include the tenant ID
    # e.g., /integrations/hubspot/webhook/:tenant_id
    tenant_id = conn.path_params["tenant_id"]

    # Process the webhook
    case Core.Integrations.HubSpot.Webhook.handle_webhook(tenant_id, params) do
      {:ok, _result} ->
        # Return 200 OK to acknowledge receipt
        send_resp(conn, 200, "")

      {:error, reason} ->
        Logger.error("Failed to process HubSpot webhook: #{inspect(reason)}")
        # Still return 200 to avoid HubSpot retrying
        send_resp(conn, 200, "")
    end
  end

  @doc """
  Disconnects the HubSpot integration.
  """
  def disconnect(conn, _params) do
    tenant_id = conn.assigns.current_tenant.id

    # Revoke the token
    OAuth.revoke_token(:hubspot)

    # Remove from registry
    Registry.remove_connection(tenant_id, :hubspot)

    # Update database
    delete_integration_connection(tenant_id, :hubspot)

    conn
    |> put_flash(:info, "HubSpot integration disconnected.")
    |> redirect(to: ~p"/integrations")
  end

  # Private functions

  defp create_integration_connection(tenant_id, provider, token) do
    # This would be implemented in your context module
    # Core.Integrations.create_integration_connection(%{
    #   tenant_id: tenant_id,
    #   provider: to_string(provider),
    #   access_token: token.access_token,
    #   refresh_token: token.refresh_token,
    #   expires_at: token.expires_at,
    #   token_type: token.token_type
    # })

    # For now, just log it
    Logger.info("Created integration connection for tenant #{tenant_id}, provider #{provider}")
    {:ok, :created}
  end

  defp delete_integration_connection(tenant_id, provider) do
    # This would be implemented in your context module
    # Core.Integrations.delete_integration_connection_by_tenant_and_provider(tenant_id, provider)

    # For now, just log it
    Logger.info("Deleted integration connection for tenant #{tenant_id}, provider #{provider}")
    {:ok, :deleted}
  end
end
