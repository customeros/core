defmodule Core.Integrations.Providers.HubSpot.Company do
  @moduledoc """
  HubSpot company integration.

  This module handles the synchronization of companies between HubSpot and our system.
  It provides functions for:
  - Fetching companies from HubSpot
  - Creating companies in HubSpot
  - Updating companies in HubSpot
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
         {:ok, response} <- Client.get("/crm/v3/objects/companies/#{company_id}") do
      {:ok, response}
    end
  end

  @doc """
  Creates a company in HubSpot.

  ## Examples

      iex> create_company(connection, %{name: "Acme Inc", domain: "acme.com"})
      {:ok, %{"id" => "123", "properties" => %{"name" => "Acme Inc"}}}
  """
  def create_company(%Connection{} = connection, attrs) do
    with {:ok, _} <- Connections.update_status(connection, :active),
         body <- %{properties: format_properties(attrs)},
         {:ok, response} <- Client.post("/crm/v3/objects/companies", body) do
      {:ok, response}
    end
  end

  @doc """
  Updates a company in HubSpot.

  ## Examples

      iex> update_company(connection, "123", %{name: "New Name"})
      {:ok, %{"id" => "123", "properties" => %{"name" => "New Name"}}}
  """
  def update_company(%Connection{} = connection, company_id, attrs) do
    with {:ok, _} <- Connections.update_status(connection, :active),
         body <- %{properties: format_properties(attrs)},
         {:ok, response} <- Client.patch("/crm/v3/objects/companies/#{company_id}", body) do
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
         {:ok, response} <- Client.get("/crm/v3/objects/companies", params) do
      {:ok, response}
    end
  end

  @doc """
  Syncs companies from HubSpot to our system.

  ## Examples

      iex> sync_companies(connection)
      {:ok, %{synced: 10, errors: 0}}
  """
  def sync_companies(%Connection{} = connection) do
    with {:ok, _} <- Connections.update_status(connection, :active),
         {:ok, %{"results" => companies}} <- list_companies(connection) do
      results = Enum.reduce(companies, %{synced: 0, errors: 0}, fn company, acc ->
        case sync_company(company) do
          {:ok, _} -> %{acc | synced: acc.synced + 1}
          {:error, _} -> %{acc | errors: acc.errors + 1}
        end
      end)

      {:ok, results}
    end
  end

  # Private functions

  defp format_properties(attrs) do
    Enum.map(attrs, fn {key, value} ->
      {String.to_atom(key), %{value: value}}
    end)
    |> Enum.into(%{})
  end

  defp sync_company(company) do
    # In a real implementation, you would:
    # 1. Transform the HubSpot company data to your format
    # 2. Create or update the company in your system
    # 3. Handle any errors that occur
    {:ok, company}
  end
end
