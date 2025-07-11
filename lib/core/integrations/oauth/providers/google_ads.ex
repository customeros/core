defmodule Core.Integrations.OAuth.Providers.GoogleAds do
  @moduledoc """
  Google Ads OAuth provider implementation.

  This module handles the OAuth flow for Google Ads integration, including:
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
    config = Application.get_env(:core, :google_ads)
    base_url = config[:auth_base_url]

    unless base_url do
      Logger.error("Google Ads auth_base_url is not configured")

      raise "Google Ads auth_base_url is not configured. Please set it in your runtime config."
    end

    client_id = config[:client_id]
    scopes = config[:scopes]
    state = generate_state(tenant_id)

    params = %{
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: Enum.join(scopes, " "),
      response_type: "code",
      access_type: "offline",
      prompt: "consent",
      state: state
    }

    encoded_params = URI.encode_query(params)

    url = "#{base_url}/o/oauth2/auth?#{encoded_params}"

    {:ok, url}
  end

  @impl Base
  def exchange_code(code, redirect_uri) do
    config = Application.get_env(:core, :google_ads)
    base_url = config[:token_base_url]

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
    {:ok, connection} =
      Connections.update_connection(connection, %{status: :refreshing})

    config = Application.get_env(:core, :google_ads)
    base_url = config[:token_base_url]

    params = %{
      grant_type: "refresh_token",
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      refresh_token: connection.refresh_token
    }

    case post_token(base_url, params) do
      {:ok, token_data} ->
        case Token.new(token_data) do
          {:ok, token} ->
            # Update connection with new tokens and set status to active temporarily
            # Note: This indicates token refresh success, but API health will be verified
            # by actual API operations
            case Connections.update_connection(connection, %{
                   access_token: token.access_token,
                   refresh_token: token.refresh_token,
                   expires_at: token.expires_at,
                   scopes: config[:scopes] || [],
                   status: :active,
                   # Clear any previous errors
                   connection_error: nil
                 }) do
              {:ok, updated} ->
                Logger.info(
                  "Token refresh successful for connection #{inspect(updated.id)}. " <>
                    "API health will be verified on next operation."
                )

                {:ok, updated}

              {:error, reason} ->
                Logger.error(
                  "Failed to update connection with new tokens: #{inspect(reason)}"
                )

                # Set status to error but keep the new tokens
                {:ok, _} =
                  Connections.update_connection(connection, %{
                    status: :error,
                    connection_error:
                      "Failed to update connection: #{inspect(reason)}"
                  })

                {:error, :update_failed}
            end

          {:error, reason} ->
            Logger.error("Failed to parse token: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to refresh token: #{inspect(reason)}")

        {:ok, _updated} =
          Connections.update_connection(connection, %{
            status: :error,
            connection_error: "Token refresh failed: #{inspect(reason)}"
          })

        {:error, reason}
    end
  end

  @impl Base
  def validate_token(%Connection{} = connection) do
    config = Application.get_env(:core, :google_ads)
    base_url = config[:api_base_url]

    url =
      "#{base_url}/oauth2/v1/tokeninfo?access_token=#{connection.access_token}"

    case make_http_get(url) do
      {:ok, %{"aud" => _audience}} ->
        {:ok, connection}

      {:error, reason} ->
        Logger.error("Token validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Gets Google Ads account information using the access token.
  Returns the customer_id and other account details.
  """
  def get_account_info(access_token) do
    config = Application.get_env(:core, :google_ads)
    base_url = config[:api_base_url]
    url = "#{base_url}/oauth2/v1/tokeninfo?access_token=#{access_token}"

    case make_http_get(url) do
      {:ok, %{"aud" => audience}} ->
        Logger.info("Token validation successful, audience: #{audience}")
        {:ok, audience}

      {:error, reason} ->
        Logger.error("Token validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Public functions for testing

  @doc false
  def generate_state(tenant_id) do
    random_bytes = :crypto.strong_rand_bytes(16)
    encoded = Elixir.Base.encode16(random_bytes, case: :lower)
    state = encoded <> "_#{tenant_id}"
    state
  end

  defp post_token(base_url, params) do
    headers = [{"content-type", "application/x-www-form-urlencoded"}]
    url = URI.parse("#{base_url}/oauth2/v4/token")
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

  defp make_http_get(url) do
    request = Finch.build(:get, url)

    case Finch.request(request, Core.Finch) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to get Google Ads API: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, %{reason: reason}} ->
        Logger.error("Failed to get Google Ads API: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
