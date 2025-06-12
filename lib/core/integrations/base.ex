defmodule Core.Integrations.Base do
  @moduledoc """
  Base behaviour module for integration providers.

  This module defines the contract that all integration providers must implement.
  It provides a standardized way to interact with external services across
  different integration providers (HubSpot, Salesforce, etc.).

  ## Usage

  ```elixir
  defmodule Core.Integrations.HubSpot do
    @behaviour Core.Integrations.Base

    # Implement required callbacks
  end
  ```

  ## Required Callbacks

  - `fetch_companies/1` - Fetch all companies from the integration provider
  - `fetch_company/2` - Fetch a specific company from the integration provider
  - `handle_webhook/2` - Handle webhook events from the integration provider
  """

  @type provider :: atom()
  @type company :: map()
  @type company_id :: String.t()
  @type webhook_data :: map()

  @callback fetch_companies(provider()) :: {:ok, [company()]} | {:error, term()}
  @callback fetch_company(provider(), company_id()) :: {:ok, company()} | {:error, term()}
  @callback handle_webhook(provider(), webhook_data()) :: {:ok, term()} | {:error, term()}
end
