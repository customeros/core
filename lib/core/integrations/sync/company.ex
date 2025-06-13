defmodule Core.Integrations.Company.Base do
  @moduledoc """
  Behaviour module for company operations in integrations.

  This module defines the contract that all company operation handlers must implement.
  It ensures consistent company data handling across different integration providers.

  ## Callbacks

  * `fetch_companies/1` - Fetches all companies from the integration provider
  * `fetch_company/2` - Fetches a specific company from the integration provider
  """

  @doc """
  Fetches all companies from the integration provider.

  ## Parameters
  - `tenant_id` - The ID of the tenant making the request

  ## Returns
  - `{:ok, companies}` - List of companies from the provider
  - `{:error, reason}` - Error fetching companies
  """
  @callback fetch_companies(tenant_id :: String.t()) ::
              {:ok, [map()]} | {:error, String.t()}

  @doc """
  Fetches a specific company from the integration provider.

  ## Parameters
  - `tenant_id` - The ID of the tenant making the request
  - `company_id` - The ID of the company to fetch

  ## Returns
  - `{:ok, company}` - Company data from the provider
  - `{:error, reason}` - Error fetching company
  """
  @callback fetch_company(tenant_id :: String.t(), company_id :: String.t()) ::
              {:ok, map()} | {:error, String.t()}
end
