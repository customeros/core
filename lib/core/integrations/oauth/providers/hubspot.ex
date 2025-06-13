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
      Logger.error("HubSpot auth_base_url is not configured")
      raise "HubSpot auth_base_url is not configured. Please set it in your runtime config."
    end

    client_id = config[:client_id]
    scopes = config[:scopes]
    state = generate_state(tenant_id)

    params = %{
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: Enum.join(scopes, " "),
      state: state
    }

    encoded_params = URI.encode_query(params)

    url = "#{base_url}/oauth/authorize?#{encoded_params}"

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
      {:ok, token_data} ->
        {:ok, Token.new(token_data)}

      {:error, reason} ->
        Logger.error("Failed to exchange code for token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl Base
  def refresh_token(%Connection{} = connection) do
    # Update connection status to refreshing
    {:ok, connection} = Connections.update_connection(connection, %{status: :refreshing})

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

        # Update connection with new tokens and set status back to active
        case Connections.update_connection(connection, %{
          access_token: token.access_token,
          refresh_token: token.refresh_token,
          expires_at: token.expires_at,
          scopes: config[:scopes] || [],
          status: :active,
          connection_error: nil  # Clear any previous errors
        }) do
          {:ok, updated} ->
            Logger.info("Successfully updated connection with new tokens: #{inspect(updated.id)}")
            {:ok, updated}

          {:error, reason} ->
            Logger.error("Failed to update connection with new tokens: #{inspect(reason)}")
            # Set status to error but keep the new tokens
            {:ok, _} = Connections.update_connection(connection, %{
              status: :error,
              connection_error: "Failed to update connection: #{inspect(reason)}"
            })
            {:error, :update_failed}
        end

      {:error, reason} ->
        Logger.error("Failed to refresh token: #{inspect(reason)}")
        {:ok, _updated} = Connections.update_connection(connection, %{
          status: :error,
          connection_error: "Token refresh failed: #{inspect(reason)}"
        })
        {:error, reason}
    end
  end

  @impl Base
  def validate_token(%Connection{} = connection) do
    config = Application.get_env(:core, :hubspot)
    base_url = config[:api_base_url]
    url = "#{base_url}/oauth/v1/access-tokens/#{connection.access_token}"
    headers = [{"authorization", "Bearer #{connection.access_token}"}]

    case make_http_get(url, headers) do
      {:ok, %{"hub_id" => _hub_id}} ->
        {:ok, connection}

      {:error, reason} ->
        Logger.error("Token validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Gets HubSpot portal information using the access token.
  Returns the hub_id (portal ID) and other portal details.
  """
  def get_portal_info(access_token) do
    config = Application.get_env(:core, :hubspot)
    base_url = config[:api_base_url]
    url = "#{base_url}/oauth/v1/access-tokens/#{access_token}"
    headers = [{"authorization", "Bearer #{access_token}"}]

    case make_http_get(url, headers) do
      {:ok, %{"hub_id" => hub_id}} ->
        Logger.info("Token validation successful, hub_id: #{hub_id}")
        {:ok, hub_id}

      {:error, reason} ->
        Logger.error("Token validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp generate_state(tenant_id) do
    random_bytes = :crypto.strong_rand_bytes(16)
    encoded = Elixir.Base.encode16(random_bytes, case: :lower)
    state = encoded <> "_#{tenant_id}"
    state
  end

  defp post_token(base_url, params) do
    headers = [{"content-type", "application/x-www-form-urlencoded"}]
    url = URI.parse("#{base_url}/oauth/v1/token")
    body = URI.encode_query(params)

    case Finch.build(:post, url, headers, body) |> Finch.request(Core.Finch) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Token request failed: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, %{reason: reason}} ->
        Logger.error("Token request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp make_http_get(url, headers) do
    request = Finch.build(:get, url, headers)

    case Finch.request(request, Core.Finch) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to get HubSpot API: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, %{reason: reason}} ->
        Logger.error("Failed to get HubSpot API: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
