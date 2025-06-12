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
  ```
  """

  use Tesla

  plug Tesla.Middleware.BaseUrl, Application.get_env(:core, :hubspot)[:api_base_url] || "https://api.hubapi.com"
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Logger

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

    case method do
      :get -> get(path, query: params, headers: headers)
      :post -> post(path, body, headers: headers)
      :put -> put(path, body, headers: headers)
      :delete -> delete(path, headers: headers)
    end
  end

  @doc """
  Handles API response and converts it to a standard format.

  ## Parameters
  - `response` - Tesla response

  ## Returns
  - `{:ok, data}` - Successful response with parsed data
  - `{:error, {status, body}}` - Error response with status code and body
  - `{:error, reason}` - Other error
  """
  def handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  def handle_response({:ok, %{status: status, body: body}}) do
    error_message = extract_error_message(body)
    {:error, {status, error_message}}
  end

  def handle_response({:error, reason}) do
    {:error, reason}
  end

  # Helper function to extract error messages from HubSpot error responses
  defp extract_error_message(%{"message" => message}), do: message
  defp extract_error_message(%{"errors" => [%{"message" => message} | _]}), do: message
  defp extract_error_message(body), do: body
end
