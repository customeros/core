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

  # TODO: Implement Tesla-based HTTP client
  # - request/3
  # - handle_response/1
end
