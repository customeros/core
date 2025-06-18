defmodule Core.Integrations.Providers.HubSpot.Companies do
  @moduledoc """
  HubSpot company integration.

  This module handles the synchronization of companies from HubSpot to our system.
  It provides functions for:
  - Fetching companies from HubSpot
  - Syncing company data between systems
  """

  require Logger
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
    with {:ok, response} <-
           Client.get(connection, "/crm/v3/objects/companies/#{company_id}") do
      # API call succeeded - connection is healthy, update status to active
      case Connections.update_status(connection, :active) do
        {:ok, _} ->
          Logger.info("[HubSpot Company] Successfully fetched company #{company_id} and updated connection status to active")
          {:ok, response}
        {:error, reason} ->
          Logger.warning("[HubSpot Company] Fetched company #{company_id} but failed to update connection status: #{inspect(reason)}")
          {:ok, response}
      end
    else
      {:error, reason} ->
        Logger.error("[HubSpot Company] Error fetching company #{company_id}: #{inspect(reason)}")

        # API call failed - update connection status to error
        case Connections.update_status(connection, :error) do
          {:ok, _} ->
            Logger.debug("[HubSpot Company] Updated connection status to error due to API failure")
          {:error, update_reason} ->
            Logger.warning("[HubSpot Company] Failed to update connection status to error: #{inspect(update_reason)}")
        end

        {:error, reason}
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
    Logger.debug("[HubSpot Company] Listing companies for connection #{connection.id} with params: #{inspect(params)}")

    with {:ok, response} <-
           Client.get(connection, "/crm/v3/objects/companies", params) do
      # API call succeeded - connection is healthy, update status to active
      case Connections.update_status(connection, :active) do
        {:ok, _} ->
          Logger.debug("[HubSpot Company] Successfully listed companies and updated connection status to active")
          {:ok, response}
        {:error, reason} ->
          Logger.warning("[HubSpot Company] Listed companies but failed to update connection status: #{inspect(reason)}")
          {:ok, response}
      end
    else
      {:error, reason} ->
        Logger.error("[HubSpot Company] Error listing companies: #{inspect(reason)}")

        # API call failed - update connection status to error
        case Connections.update_status(connection, :error) do
          {:ok, _} ->
            Logger.debug("[HubSpot Company] Updated connection status to error due to API failure")
          {:error, update_reason} ->
            Logger.warning("[HubSpot Company] Failed to update connection status to error: #{inspect(update_reason)}")
        end

        {:error, reason}
    end
  end

  @doc """
  Fetches a company from HubSpot by tenant ID and company ID.

  Looks up the HubSpot connection for the given tenant, ensures the token is valid (refreshing if needed),
  and fetches the company details from HubSpot.

  ## Examples

      iex> get_company_by_tenant("tenant_123", "456")
      {:ok, %{"id" => "456", ...}}

      iex> get_company_by_tenant("unknown_tenant", "456")
      {:error, :not_found}
  """
  def get_company_by_tenant(tenant_id, company_id) when is_binary(tenant_id) and is_binary(company_id) do
    case Connections.get_connection(tenant_id, :hubspot) do
      {:ok, %Connection{} = connection} ->
        get_company(connection, company_id)
      {:error, :not_found} ->
        {:error, :not_found}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
