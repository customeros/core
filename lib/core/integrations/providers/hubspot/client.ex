defmodule Core.Integrations.Providers.HubSpot.Client do
  @moduledoc """
  Client for interacting with the HubSpot API.

  This module provides functions for making authenticated requests to the HubSpot API,
  handling rate limiting, and managing API responses.
  """

  alias Core.Integrations.{Connection, Connections}
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

  ## Parameters
    - connection - The integration connection
    - path - The API endpoint path
    - params - Optional query parameters

  ## Returns
    - `{:ok, map()}` - The parsed JSON response
    - `{:error, term()}` - Error reason
  """
  def get(%Connection{} = connection, path, params \\ %{}) do
    url = build_url(path, params)
    headers = [{"authorization", "Bearer #{connection.access_token}"}]

    case Finch.request(:get, url, headers, "", pool: :hubspot) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

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
    url = build_url(path, params)
    headers = [
      {"authorization", "Bearer #{connection.access_token}"},
      {"content-type", "application/json"}
    ]

    case Finch.request(:post, url, headers, Jason.encode!(body), pool: :hubspot) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, Jason.decode!(body)}

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
    url = build_url(path, params)
    headers = [
      {"authorization", "Bearer #{connection.access_token}"},
      {"content-type", "application/json"}
    ]

    case Finch.request(:put, url, headers, Jason.encode!(body), pool: :hubspot) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, Jason.decode!(body)}

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

  ## Parameters
    - connection - The integration connection
    - path - The API endpoint path
    - params - Optional query parameters

  ## Returns
    - `{:ok, map()}` - The parsed JSON response
    - `{:error, term()}` - Error reason
  """
  def delete(%Connection{} = connection, path, params \\ %{}) do
    url = build_url(path, params)
    headers = [{"authorization", "Bearer #{connection.access_token}"}]

    case Finch.request(:delete, url, headers, "", pool: :hubspot) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to delete HubSpot API: HTTP #{status}: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, reason} ->
        Logger.error("Failed to delete HubSpot API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp build_url(path, params) do
    query_string =
      params
      |> Enum.map(fn {key, value} -> "#{key}=#{URI.encode_www_form(to_string(value))}" end)
      |> Enum.join("&")

    url = "#{base_url()}#{path}"
    if query_string == "", do: url, else: "#{url}?#{query_string}"
  end
end
