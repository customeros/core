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
    config = Application.get_env(:core, :hubspot)
    base_url = config[:auth_base_url]

    unless base_url do
      raise "HubSpot auth_base_url is not configured. Please set it in your runtime config."
    end

    client_id = config[:client_id]
    client_secret = config[:client_secret]
    scopes = config[:scopes]
    state = generate_state(tenant_id)

    Logger.debug("HubSpot OAuth config: base_url=#{base_url}, client_id=#{client_id}, redirect_uri=#{redirect_uri}, scopes=#{inspect(scopes)}")

    params = %{
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: Enum.join(scopes, " "),
      state: state
    }

    url = "#{base_url}/oauth/authorize?#{URI.encode_query(params)}"
    Logger.debug("Generated HubSpot OAuth URL: #{url}")
    {:ok, url}
  end

  @impl Base
  def exchange_code(code, redirect_uri) do
    config = Application.get_env(:core, :hubspot)
    base_url = config[:api_base_url]
    params = %{
      grant_type: "authorization_code",
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      redirect_uri: redirect_uri,
      code: code
    }

    case post_token(base_url, params) do
      {:ok, token_data} -> {:ok, Token.new(token_data)}
      error -> error
    end
  end

  @impl Base
  def refresh_token(%Connection{} = connection) do
    config = Application.get_env(:core, :hubspot)
    base_url = config[:api_base_url]
    params = %{
      grant_type: "refresh_token",
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      refresh_token: connection.refresh_token
    }

    case post_token(base_url, params) do
      {:ok, token_data} ->
        token = Token.new(token_data)
        Connections.update_connection(connection, %{
          access_token: token.access_token,
          refresh_token: token.refresh_token,
          expires_at: token.expires_at,
          scopes: token.scopes,
          status: :active
        })

      {:error, reason} ->
        Connections.update_connection(connection, %{
          status: :error,
          last_sync_error: "Token refresh failed: #{inspect(reason)}"
        })
    end
  end

  @impl Base
  def validate_token(%Connection{} = connection) do
    case get(connection) do
      {:ok, %{"user" => _user}} -> {:ok, connection}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get(connection) do
    config = Application.get_env(:core, :hubspot)
    base_url = config[:api_base_url]
    headers = [{"authorization", "Bearer #{connection.access_token}"}]

    case HTTPoison.get("#{base_url}/oauth/v1/access-tokens/#{connection.access_token}", headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status, body: body}} ->
        {:error, "HTTP #{status}: #{body}"}

      {:error, %{reason: reason}} ->
        {:error, reason}
    end
  end

  # Private functions

  defp generate_state(tenant_id) do
    random_bytes = :crypto.strong_rand_bytes(16)
    encoded = Elixir.Base.encode16(random_bytes, case: :lower)
    encoded <> "_#{tenant_id}"
  end

  defp post_token(base_url, params) do
    headers = [{"content-type", "application/x-www-form-urlencoded"}]
    url = "#{base_url}/oauth/v1/token"

    Logger.debug("Posting to HubSpot token endpoint: #{url}")
    Logger.debug("Token request params: #{inspect(params, sensitive: true)}")

    case HTTPoison.post(url, URI.encode_query(params), headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status, body: body}} ->
        Logger.error("HubSpot token request failed: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, %{reason: reason}} ->
        Logger.error("HubSpot token request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
