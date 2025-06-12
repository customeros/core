defmodule Core.Integrations.HubSpot.OAuth do
  @moduledoc """
  HubSpot OAuth implementation.

  This module implements the OAuth flow for HubSpot integration.
  It handles the OAuth2 authentication process including:
  - Authorization URL generation
  - Token exchange
  - Token refresh
  - Token revocation

  ## Configuration

  The following configuration is required in your config:

  ```elixir
  config :core, :hubspot,
    client_id: "your_client_id",
    client_secret: "your_client_secret",
    redirect_uri: "your_redirect_uri",
    scopes: ["crm.objects.companies.read"]
  ```

  ## Usage

  ```elixir
  # Generate authorization URL
  {:ok, url} = Core.Integrations.HubSpot.OAuth.authorize_url(:hubspot)

  # Exchange code for token
  {:ok, token} = Core.Integrations.HubSpot.OAuth.get_token(:hubspot, "authorization_code")

  # Refresh token
  {:ok, new_token} = Core.Integrations.HubSpot.OAuth.refresh_token(:hubspot)
  ```
  """

  @behaviour Core.Integrations.OAuth.Base
  alias Core.Integrations.HubSpot.Client
  require Logger

  @impl true
  def authorize_url(_provider) do
    config = Application.get_env(:core, :hubspot)

    query_params = %{
      client_id: config[:client_id],
      redirect_uri: config[:redirect_uri],
      scope: Enum.join(config[:scopes], " ")
    }

    auth_url = "#{config[:auth_base_url] || "https://app.hubspot.com"}/oauth/authorize"
    url = "#{auth_url}?#{URI.encode_query(query_params)}"

    {:ok, url}
  end

  @impl true
  def get_token(_provider, code) do
    config = Application.get_env(:core, :hubspot)

    body = %{
      grant_type: "authorization_code",
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      redirect_uri: config[:redirect_uri],
      code: code
    }

    case Client.request(:post, "/oauth/v1/token", body: body) do
      {:ok, response} ->
        case Client.handle_response(response) do
          {:ok, token_data} ->
            token = %{
              access_token: token_data["access_token"],
              refresh_token: token_data["refresh_token"],
              expires_at: calculate_expiry(token_data["expires_in"]),
              token_type: token_data["token_type"]
            }
            {:ok, token}

          {:error, reason} ->
            Logger.error("Failed to get HubSpot token: #{inspect(reason)}")
            {:error, "Failed to get access token"}
        end

      {:error, reason} ->
        Logger.error("HubSpot token request failed: #{inspect(reason)}")
        {:error, "Token request failed"}
    end
  end

  @impl true
  def refresh_token(_provider) do
    config = Application.get_env(:core, :hubspot)

    # In a real implementation, you would retrieve the refresh token
    # from your database or other storage
    refresh_token = "stored_refresh_token"

    body = %{
      grant_type: "refresh_token",
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      refresh_token: refresh_token
    }

    case Client.request(:post, "/oauth/v1/token", body: body) do
      {:ok, response} ->
        case Client.handle_response(response) do
          {:ok, token_data} ->
            token = %{
              access_token: token_data["access_token"],
              refresh_token: token_data["refresh_token"],
              expires_at: calculate_expiry(token_data["expires_in"]),
              token_type: token_data["token_type"]
            }
            {:ok, token}

          {:error, reason} ->
            Logger.error("Failed to refresh HubSpot token: #{inspect(reason)}")
            {:error, "Failed to refresh access token"}
        end

      {:error, reason} ->
        Logger.error("HubSpot token refresh failed: #{inspect(reason)}")
        {:error, "Token refresh failed"}
    end
  end

  @impl true
  def revoke_token(_provider) do
    # HubSpot doesn't have a specific token revocation endpoint
    # To revoke access, you typically delete the tokens from your storage
    # and stop using them

    # In a real implementation, you would delete the tokens from your database
    Logger.info("Revoking HubSpot token (deleting from storage)")

    :ok
  end

  # Helper function to calculate token expiry time
  defp calculate_expiry(expires_in) when is_integer(expires_in) do
    DateTime.add(DateTime.utc_now(), expires_in, :second)
  end
  defp calculate_expiry(expires_in) when is_binary(expires_in) do
    case Integer.parse(expires_in) do
      {seconds, _} -> calculate_expiry(seconds)
      :error -> DateTime.add(DateTime.utc_now(), 3600, :second) # Default 1 hour
    end
  end
  defp calculate_expiry(_) do
    # Default expiry of 1 hour if expires_in is not provided
    DateTime.add(DateTime.utc_now(), 3600, :second)
  end

  @impl true
  def fetch_companies(provider) do
    # TODO: Implement company fetching from HubSpot
    {:error, :not_implemented}
  end

  @impl true
  def fetch_company(provider, company_id) do
    # TODO: Implement single company fetching from HubSpot
    {:error, :not_implemented}
  end

  @impl true
  def handle_webhook(provider, webhook_data) do
    # TODO: Implement webhook handling
    {:error, :not_implemented}
  end
end
