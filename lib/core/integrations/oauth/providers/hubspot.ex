defmodule Core.Integrations.OAuth.Providers.HubSpot do
  @moduledoc """
  HubSpot OAuth provider implementation.

  This module handles the OAuth flow for HubSpot integration, including:
  - Authorization URL generation
  - Token exchange
  - Token refresh
  - Token validation
  """

  require Logger
  alias Core.Integrations.OAuth.{Base, Token}
  alias Core.Integrations.Connection
  alias Core.Integrations.Connections

  @behaviour Base

  @impl Base
  def authorize_url(tenant_id, redirect_uri) do
    Logger.debug("=== HubSpot OAuth Debug ===")
    Logger.debug("1. Starting authorization for tenant: #{tenant_id}")
    Logger.debug("2. Raw redirect URI received: #{inspect(redirect_uri)}")
    Logger.debug("3. Redirect URI parsed: #{inspect(URI.parse(redirect_uri))}")

    config = Application.get_env(:core, :hubspot)
    base_url = config[:auth_base_url]

    unless base_url do
      Logger.error("HubSpot auth_base_url is not configured")
      raise "HubSpot auth_base_url is not configured. Please set it in your runtime config."
    end

    client_id = config[:client_id]
    client_secret = config[:client_secret]
    scopes = config[:scopes]
    state = generate_state(tenant_id)

    Logger.debug("4. HubSpot config:")
    Logger.debug("   - auth_base_url: #{base_url}")
    Logger.debug("   - client_id: #{client_id}")
    Logger.debug("   - redirect_uri: #{inspect(redirect_uri)}")
    Logger.debug("   - scopes: #{inspect(scopes)}")
    Logger.debug("   - state: #{state}")

    params = %{
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: Enum.join(scopes, " "),
      state: state
    }

    Logger.debug("5. OAuth parameters before encoding:")
    Logger.debug("   #{inspect(params, pretty: true)}")

    encoded_params = URI.encode_query(params)
    Logger.debug("6. Encoded query string:")
    Logger.debug("   #{encoded_params}")

    url = "#{base_url}/oauth/authorize?#{encoded_params}"
    Logger.debug("7. Final OAuth URL:")
    Logger.debug("   #{url}")
    Logger.debug("8. URL components:")
    Logger.debug("   #{inspect(URI.parse(url), pretty: true)}")
    Logger.debug("=== End HubSpot OAuth Debug ===")

    {:ok, url}
  end

  @impl Base
  def exchange_code(code, redirect_uri) do
    Logger.debug("Exchanging HubSpot authorization code for token")
    Logger.debug("Using redirect URI: #{redirect_uri}")

    config = Application.get_env(:core, :hubspot)
    base_url = config[:api_base_url]
    params = %{
      grant_type: "authorization_code",
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      redirect_uri: redirect_uri,
      code: code
    }

    Logger.debug("Token exchange params: #{inspect(params, sensitive: true)}")

    case post_token(base_url, params) do
      {:ok, token_data} ->
        Logger.debug("Successfully exchanged code for token: #{inspect(token_data, sensitive: true)}")
        {:ok, Token.new(token_data)}

      {:error, reason} ->
        Logger.error("Failed to exchange code for token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl Base
  def refresh_token(%Connection{} = connection) do
    Logger.debug("Refreshing HubSpot token for connection: #{inspect(connection.id)}")

    config = Application.get_env(:core, :hubspot)
    base_url = config[:api_base_url]
    params = %{
      grant_type: "refresh_token",
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      refresh_token: connection.refresh_token
    }

    Logger.debug("Token refresh params: #{inspect(params, sensitive: true)}")

    case post_token(base_url, params) do
      {:ok, token_data} ->
        Logger.debug("Successfully refreshed token: #{inspect(token_data, sensitive: true)}")
        token = Token.new(token_data)
        Connections.update_connection(connection, %{
          access_token: token.access_token,
          refresh_token: token.refresh_token,
          expires_at: token.expires_at,
          scopes: token.scopes,
          status: :active
        })

      {:error, reason} ->
        Logger.error("Failed to refresh token: #{inspect(reason)}")
        Connections.update_connection(connection, %{
          status: :error,
          last_sync_error: "Token refresh failed: #{inspect(reason)}"
        })
    end
  end

  @impl Base
  def validate_token(%Connection{} = connection) do
    Logger.debug("Validating HubSpot token for connection: #{inspect(connection.id)}")

    case get(connection) do
      {:ok, %{"user" => user}} ->
        Logger.debug("Token validation successful: #{inspect(user)}")
        {:ok, connection}

      {:error, reason} ->
        Logger.error("Token validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def get(connection) do
    Logger.debug("Getting HubSpot user info for connection: #{inspect(connection.id)}")

    config = Application.get_env(:core, :hubspot)
    base_url = config[:api_base_url]
    headers = [{"authorization", "Bearer #{connection.access_token}"}]

    url = "#{base_url}/oauth/v1/access-tokens/#{connection.access_token}"
    Logger.debug("Making request to: #{url}")

    case HTTPoison.get(url, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        Logger.debug("Successfully got user info: #{inspect(body)}")
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status, body: body}} ->
        Logger.error("Failed to get user info: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, %{reason: reason}} ->
        Logger.error("Failed to get user info: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp generate_state(tenant_id) do
    random_bytes = :crypto.strong_rand_bytes(16)
    encoded = Elixir.Base.encode16(random_bytes, case: :lower)
    state = encoded <> "_#{tenant_id}"
    Logger.debug("Generated state: #{state}")
    state
  end

  defp post_token(base_url, params) do
    headers = [{"content-type", "application/x-www-form-urlencoded"}]
    url = URI.parse("#{base_url}/oauth/v1/token")
    body = URI.encode_query(params)

    Logger.debug("Posting to HubSpot token endpoint: #{url}")
    Logger.debug("Token request params: #{inspect(params, sensitive: true)}")

    case Finch.build(:post, url, headers, body) |> Finch.request(Core.Finch) do
      {:ok, %{status: 200, body: body}} ->
        Logger.debug("Token request successful: #{inspect(body, sensitive: true)}")
        {:ok, Jason.decode!(body)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Token request failed: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, %{reason: reason}} ->
        Logger.error("Token request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
