defmodule Core.Integrations.Providers.HubSpot.Company do
  @moduledoc """
  HubSpot company integration.

  This module handles the synchronization of companies from HubSpot to our system.
  It provides functions for:
  - Fetching companies from HubSpot
  - Syncing company data between systems
  """

  alias Core.Integrations.Providers.HubSpot.Client
  alias Core.Integrations.Connection
  alias Core.Integrations.Connections

  @doc """
  Fetches a company from HubSpot by ID.

  ## Examples

      iex> get_company(connection, "123")
      {:ok, %{"id" => "123", "properties" => %{"name" => "Acme Inc"}}}
  """
  def get_company(%Connection{} = connection, company_id) do
    with {:ok, _} <- Connections.update_status(connection, :active),
         {:ok, response} <-
           Client.get(connection, "/crm/v3/objects/companies/#{company_id}") do
      {:ok, response}
    end
  end

  @doc """
  Lists companies from HubSpot.

  ## Examples

      iex> list_companies(connection)
      {:ok, %{"results" => [...]}}

      iex> list_companies(connection, %{limit: 10, after: "123"})
      {:ok, %{"results" => [...]}}
  """
  def list_companies(%Connection{} = connection, params \\ %{}) do
    with {:ok, _} <- Connections.update_status(connection, :active),
         {:ok, response} <-
           Client.get(connection, "/crm/v3/objects/companies", params) do
      {:ok, response}
    end
  end
end
