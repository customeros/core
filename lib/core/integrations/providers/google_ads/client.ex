defmodule Core.Integrations.Providers.GoogleAds.Client do
  @moduledoc """
  Client for interacting with the Google Ads API.

  This module provides functions for making authenticated requests to the Google Ads API,
  handling rate limiting, and managing API responses.
  """

  alias Core.Integrations.Connection
  alias Core.Integrations.OAuth.TokenManager
  alias Core.Integrations.Registry
  require Logger

  @doc """
  Gets the base URL for Google Ads API calls.
  """
  def base_url do
    config = Application.get_env(:core, :google_ads)
    base = config[:api_base_url] || raise "Google Ads api_base_url is not configured"
    base
  end

  @doc """
  Makes a GET request to the Google Ads API.

  This function:
  1. Ensures the token is valid (refreshing if needed)
  2. Makes the API request
  3. Handles rate limiting and errors

  ## Parameters
    - connection - The integration connection
    - path - The API endpoint path
    - params - Optional query parameters
    - customer_id - Optional customer ID to use for the request (defaults to connection.external_system_id)

  ## Returns
    - `{:ok, map()}` - The parsed JSON response
    - `{:error, term()}` - Error reason
  """
  def get(%Connection{} = connection, path, params \\ %{}, customer_id \\ nil) do
    with {:ok, connection} <- ensure_valid_token(connection),
         url = build_url(path, params),
         headers = build_headers(connection, customer_id),
         {:ok, %{status: 200, body: body}} <-
           Finch.build(:get, url, headers, "")
           |> Finch.request(Core.Finch) do
      {:ok, Jason.decode!(body)}
    else
      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to get Google Ads API: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, reason} ->
        Logger.error("Failed to get Google Ads API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Makes a POST request to the Google Ads API.

  This function:
  1. Ensures the token is valid (refreshing if needed)
  2. Makes the API request
  3. Handles rate limiting and errors

  ## Parameters
    - connection - The integration connection
    - path - The API endpoint path
    - body - The request body
    - params - Optional query parameters
    - customer_id - Optional customer ID to use for the request (defaults to connection.external_system_id)

  ## Returns
    - `{:ok, map()}` - The parsed JSON response
    - `{:error, term()}` - Error reason
  """
  def post(%Connection{} = connection, path, body, params \\ %{}, customer_id \\ nil) do
    with {:ok, connection} <- ensure_valid_token(connection),
         url = build_url(path, params),
         headers = build_headers(connection, customer_id),
         encoded_body = Jason.encode!(body) do
      case Finch.build(:post, url, headers, encoded_body)
           |> Finch.request(Core.Finch) do
        {:ok, %{status: status, body: response_body}} when status in 200..299 ->
          case Jason.decode(response_body) do
            {:ok, decoded} -> {:ok, decoded}
            {:error, _} -> {:error, "Failed to decode response: #{response_body}"}
          end

        {:ok, %{status: status, body: response_body}} ->
          Logger.error("Failed to post Google Ads API: HTTP #{status}: #{response_body}")
          {:error, "HTTP #{status}: #{response_body}"}

        {:error, reason} ->
          Logger.error("Failed to post Google Ads API: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @doc """
  Makes a PUT request to the Google Ads API.

  This function:
  1. Ensures the token is valid (refreshing if needed)
  2. Makes the API request
  3. Handles rate limiting and errors

  ## Parameters
    - connection - The integration connection
    - path - The API endpoint path
    - body - The request body
    - params - Optional query parameters
    - customer_id - Optional customer ID to use for the request (defaults to connection.external_system_id)

  ## Returns
    - `{:ok, map()}` - The parsed JSON response
    - `{:error, term()}` - Error reason
  """
  def put(%Connection{} = connection, path, body, params \\ %{}, customer_id \\ nil) do
    with {:ok, connection} <- ensure_valid_token(connection),
         url = build_url(path, params),
         headers = build_headers(connection, customer_id),
         {:ok, %{status: status, body: body}} when status in 200..299 <-
           Finch.build(:put, url, headers, Jason.encode!(body))
           |> Finch.request(Core.Finch) do
      {:ok, Jason.decode!(body)}
    else
      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to put Google Ads API: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, reason} ->
        Logger.error("Failed to put Google Ads API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Makes a DELETE request to the Google Ads API.

  This function:
  1. Ensures the token is valid (refreshing if needed)
  2. Makes the API request
  3. Handles rate limiting and errors

  ## Parameters
    - connection - The integration connection
    - path - The API endpoint path
    - params - Optional query parameters
    - customer_id - Optional customer ID to use for the request (defaults to connection.external_system_id)

  ## Returns
    - `{:ok, map()}` - The parsed JSON response
    - `{:error, term()}` - Error reason
  """
  def delete(%Connection{} = connection, path, params \\ %{}, customer_id \\ nil) do
    with {:ok, connection} <- ensure_valid_token(connection),
         url = build_url(path, params),
         headers = build_headers(connection, customer_id),
         {:ok, %{status: status, body: body}} when status in 200..299 <-
           Finch.build(:delete, url, headers, "")
           |> Finch.request(Core.Finch) do
      {:ok, Jason.decode!(body)}
    else
      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to delete Google Ads API: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, reason} ->
        Logger.error("Failed to delete Google Ads API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Revokes a Google Ads OAuth access token via the Google OAuth API.
  Returns :ok on success, {:error, reason} on failure.
  """
  def revoke_token(access_token) when is_binary(access_token) do
    url = "https://oauth2.googleapis.com/revoke"
    headers = [{"content-type", "application/x-www-form-urlencoded"}]
    body = URI.encode_query(%{"token" => access_token})

    case Finch.build(:post, url, headers, body) |> Finch.request(Core.Finch) do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status, body: resp_body}} ->
        Logger.error(
          "Failed to revoke Google Ads token: HTTP #{status}: #{resp_body}"
        )

        {:error, "HTTP #{status}: #{resp_body}"}

      {:error, reason} ->
        Logger.error("Failed to revoke Google Ads token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp ensure_valid_token(%Connection{} = connection) do
    case TokenManager.ensure_valid_token(connection) do
      {:ok, refreshed} ->
        {:ok, refreshed}

      :refresh_needed ->
        # Token needs refresh, try to refresh it directly
        case Registry.get_oauth(connection.provider) do
          {:ok, oauth} ->
            case oauth.refresh_token(connection) do
              {:ok, refreshed} ->
                {:ok, refreshed}

              {:error, reason} ->
                Logger.error("Token refresh failed: #{inspect(reason)}")
                {:error, "Token refresh failed: #{inspect(reason)}"}
            end

          {:error, reason} ->
            Logger.error("OAuth provider not found: #{inspect(reason)}")
            {:error, "OAuth provider not found: #{inspect(reason)}"}
        end

      {:error, reason} ->
        Logger.error("Token refresh failed: #{inspect(reason)}")
        {:error, "Token refresh failed: #{inspect(reason)}"}
    end
  end

  defp build_url(path, params) do
    url = "#{base_url()}#{path}"

    case Enum.empty?(params) do
      true -> url
      false ->
        query_string =
          params
          |> Enum.map_join("&", fn {key, value} ->
            "#{key}=#{URI.encode_www_form(to_string(value))}"
          end)
        "#{url}?#{query_string}"
    end
  end

  defp build_headers(connection, customer_id) do
    config = Application.get_env(:core, :google_ads)
    base_headers = [
      {"authorization", "Bearer #{connection.access_token}"},
      {"content-type", "application/json"},
      {"developer-token", config[:developer_token]}
    ]

    # Add login-customer-id header only if customer_id is different from the connection's ID
    case customer_id do
      nil -> base_headers
      id when id == connection.external_system_id -> base_headers
      id -> [{"login-customer-id", id} | base_headers]
    end
  end
end
