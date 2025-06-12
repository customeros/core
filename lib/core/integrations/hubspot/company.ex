defmodule Core.Integrations.HubSpot.Company do
  @moduledoc """
  HubSpot company operations.

  This module handles all company-related operations with HubSpot,
  including fetching companies and individual company details.

  ## Usage

  ```elixir
  # Fetch all companies
  {:ok, companies} = Core.Integrations.HubSpot.Company.fetch_companies(:hubspot)

  # Fetch a specific company
  {:ok, company} = Core.Integrations.HubSpot.Company.fetch_company(:hubspot, "company_id")
  ```
  """

  @behaviour Core.Integrations.Base

  @impl true
  def fetch_companies(provider) do
    # TODO: Implement company fetching from HubSpot
    {:error, :not_implemented}
  end

  @impl true
  def fetch_company(provider, company_id) do
    # TODO: Implement single company fetching from HubSpot
    {:error, :not_implemented}
  end
end
