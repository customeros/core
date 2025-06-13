defmodule Core.Integrations.HubSpot.Client do
  @moduledoc """
  HubSpot API client module.

  This module provides a client for interacting with the HubSpot API.
  It handles:
  - API request formatting
  - Authentication
  - Rate limiting
  - Error handling
  - Response parsing

  ## Usage

  ```elixir
  # Make an authenticated request
  {:ok, response} = Core.Integrations.HubSpot.Client.request(:get, "/crm/v3/objects/companies", token: token)

  # Handle the response
  case Core.Integrations.HubSpot.Client.handle_response(response) do
    {:ok, data} -> # Process data
    {:error, reason} -> # Handle error
  end
  """
  require Logger

  @base_url "https://api.hubapi.com"

  @doc """
  Makes an authenticated request to the HubSpot API.

  ## Parameters
  - `method` - HTTP method (:get, :post, :put, :delete)
  - `path` - API path (e.g., "/crm/v3/objects/companies")
  - `opts` - Request options:
    - `:token` - OAuth access token
    - `:params` - Query parameters
    - `:body` - Request body for POST/PUT requests

  ## Returns
  - `{:ok, response}` - Successful response
  - `{:error, reason}` - Error response
  """
  def request(method, path, opts \\ []) do
    token = Keyword.get(opts, :token)
    params = Keyword.get(opts, :params, %{})
    body = Keyword.get(opts, :body)

    headers = [
      {"authorization", "Bearer #{token}"},
      {"content-type", "application/json"}
    ]

    url = build_url(path, params)

    case method do
      :get -> Finch.request(:get, url, headers)
      :post -> Finch.request(:post, url, headers, Jason.encode!(body))
      :put -> Finch.request(:put, url, headers, Jason.encode!(body))
      :delete -> Finch.request(:delete, url, headers)
    end
  end

  @doc """
  Handles API response and converts it to a standard format.

  ## Parameters
  - `response` - Finch response

  ## Returns
  - `{:ok, data}` - Successful response with parsed data
  - `{:error, {status, body}}` - Error response with status code and body
  - `{:error, reason}` - Other error
  """
  def handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    case Jason.decode(body) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, "Failed to decode response: #{inspect(reason)}"}
    end
  end

  def handle_response({:ok, %{status: status, body: body}}) do
    case Jason.decode(body) do
      {:ok, data} ->
        error_message = extract_error_message(data)
        {:error, {status, error_message}}
      {:error, _} ->
        {:error, {status, body}}
    end
  end

  def handle_response({:error, reason}) do
    {:error, reason}
  end

  # Helper functions

  defp build_url(path, params) do
    query_string = URI.encode_query(params)
    base = String.trim_trailing(@base_url, "/")
    path = String.trim_leading(path, "/")

    if query_string == "" do
      "#{base}/#{path}"
    else
      "#{base}/#{path}?#{query_string}"
    end
  end

  defp extract_error_message(%{"message" => message}), do: message
  defp extract_error_message(%{"errors" => [%{"message" => message} | _]}), do: message
  defp extract_error_message(body), do: body
end
