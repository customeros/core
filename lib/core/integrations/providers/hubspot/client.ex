defmodule Core.Integrations.Providers.HubSpot.Client do
  @moduledoc """
  Client for interacting with the HubSpot API.

  This module provides functions for making authenticated requests to the HubSpot API,
  handling rate limiting, and managing API responses.
  """

  alias Core.Integrations.Connection
  alias Core.Integrations.OAuth.TokenManager
  alias Core.Integrations.Registry
  require Logger

  @doc """
  Gets the base URL for HubSpot API calls.
  """
  def base_url do
    config = Application.get_env(:core, :hubspot)
    base_url = config[:api_base_url]

    unless base_url do
      raise "HubSpot api_base_url is not configured. Please set it in your runtime config."
    end

    base_url
  end

  @doc """
  Makes a GET request to the HubSpot API.

  This function:
  1. Ensures the token is valid (refreshing if needed)
  2. Makes the API request
  3. Handles rate limiting and errors

  ## Parameters
    - connection - The integration connection
    - path - The API endpoint path
    - params - Optional query parameters

  ## Returns
    - `{:ok, map()}` - The parsed JSON response
    - `{:error, term()}` - Error reason
  """
  def get(%Connection{} = connection, path, params \\ %{}) do
    with {:ok, connection} <- ensure_valid_token(connection),
         url = build_url(path, params),
         headers = [{"authorization", "Bearer #{connection.access_token}"}],
         {:ok, %{status: 200, body: body}} <-
           Finch.build(:get, url, headers, "")
           |> Finch.request(Core.Finch) do
      {:ok, Jason.decode!(body)}
    else
      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to get HubSpot API: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, reason} ->
        Logger.error("Failed to get HubSpot API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Makes a POST request to the HubSpot API.

  This function:
  1. Ensures the token is valid (refreshing if needed)
  2. Makes the API request
  3. Handles rate limiting and errors

  ## Parameters
    - connection - The integration connection
    - path - The API endpoint path
    - body - The request body
    - params - Optional query parameters

  ## Returns
    - `{:ok, map()}` - The parsed JSON response
    - `{:error, term()}` - Error reason
  """
  def post(%Connection{} = connection, path, body, params \\ %{}) do
    with {:ok, connection} <- ensure_valid_token(connection),
         url = build_url(path, params),
         headers = [
           {"authorization", "Bearer #{connection.access_token}"},
           {"content-type", "application/json"}
         ],
         {:ok, %{status: status, body: body}} when status in 200..299 <-
           Finch.build(:post, url, headers, Jason.encode!(body))
           |> Finch.request(Core.Finch) do
      {:ok, Jason.decode!(body)}
    else
      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to post HubSpot API: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, reason} ->
        Logger.error("Failed to post HubSpot API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Makes a PUT request to the HubSpot API.

  This function:
  1. Ensures the token is valid (refreshing if needed)
  2. Makes the API request
  3. Handles rate limiting and errors

  ## Parameters
    - connection - The integration connection
    - path - The API endpoint path
    - body - The request body
    - params - Optional query parameters

  ## Returns
    - `{:ok, map()}` - The parsed JSON response
    - `{:error, term()}` - Error reason
  """
  def put(%Connection{} = connection, path, body, params \\ %{}) do
    with {:ok, connection} <- ensure_valid_token(connection),
         url = build_url(path, params),
         headers = [
           {"authorization", "Bearer #{connection.access_token}"},
           {"content-type", "application/json"}
         ],
         {:ok, %{status: status, body: body}} when status in 200..299 <-
           Finch.build(:put, url, headers, Jason.encode!(body))
           |> Finch.request(Core.Finch) do
      {:ok, Jason.decode!(body)}
    else
      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to put HubSpot API: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, reason} ->
        Logger.error("Failed to put HubSpot API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Makes a DELETE request to the HubSpot API.

  This function:
  1. Ensures the token is valid (refreshing if needed)
  2. Makes the API request
  3. Handles rate limiting and errors

  ## Parameters
    - connection - The integration connection
    - path - The API endpoint path
    - params - Optional query parameters

  ## Returns
    - `{:ok, map()}` - The parsed JSON response
    - `{:error, term()}` - Error reason
  """
  def delete(%Connection{} = connection, path, params \\ %{}) do
    with {:ok, connection} <- ensure_valid_token(connection),
         url = build_url(path, params),
         headers = [{"authorization", "Bearer #{connection.access_token}"}],
         {:ok, %{status: status, body: body}} when status in 200..299 <-
           Finch.build(:delete, url, headers, "")
           |> Finch.request(Core.Finch) do
      {:ok, Jason.decode!(body)}
    else
      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to delete HubSpot API: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, reason} ->
        Logger.error("Failed to delete HubSpot API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Revokes a HubSpot OAuth access token via the HubSpot API.
  Returns :ok on success, {:error, reason} on failure.
  """
  def revoke_token(access_token) when is_binary(access_token) do
    url = "https://api.hubapi.com/oauth/v1/access-tokens/revoke"
    headers = [{"content-type", "application/json"}]
    body = Jason.encode!(%{"token" => access_token})

    case Finch.build(:post, url, headers, body) |> Finch.request(Core.Finch) do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status, body: resp_body}} ->
        Logger.error(
          "Failed to revoke HubSpot token: HTTP #{status}: #{resp_body}"
        )

        {:error, "HTTP #{status}: #{resp_body}"}

      {:error, reason} ->
        Logger.error("Failed to revoke HubSpot token: #{inspect(reason)}")
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
                {:error, "Token refresh failed: #{inspect(reason)}"}
            end

          {:error, reason} ->
            {:error, "OAuth provider not found: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Token refresh failed: #{inspect(reason)}"}
    end
  end

  defp build_url(path, params) do
    query_string =
      params
      |> Enum.map_join("&", fn {key, value} ->
        "#{key}=#{URI.encode_www_form(to_string(value))}"
      end)

    url = "#{base_url()}#{path}"
    if query_string == "", do: url, else: "#{url}?#{query_string}"
  end
end
