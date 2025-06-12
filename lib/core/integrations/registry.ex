defmodule Core.Integrations.Registry do
  @moduledoc """
  Registry module for managing tenant-specific integrations.

  This module provides a centralized way to manage and access integration
  connections for different tenants. It handles:
  - Registration of integration providers
  - Retrieval of tenant-specific integration connections
  - Management of integration states

  ## Usage

  ```elixir
  # Get an integration connection for a tenant
  connection = Core.Integrations.Registry.get_connection(tenant_id, :hubspot)

  # Register a new integration connection
  :ok = Core.Integrations.Registry.register_connection(tenant_id, :hubspot, connection)

  # Remove an integration connection
  :ok = Core.Integrations.Registry.remove_connection(tenant_id, :hubspot)
  ```
  """
  use GenServer
  require Logger

  # Client API

  @doc """
  Starts the integration registry.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Gets an integration connection for a specific tenant and provider.
  Returns nil if no connection exists.
  """
  def get_connection(tenant_id, provider) do
    GenServer.call(__MODULE__, {:get_connection, tenant_id, provider})
  end

  @doc """
  Registers an integration connection for a specific tenant and provider.
  """
  def register_connection(tenant_id, provider, connection) do
    GenServer.call(__MODULE__, {:register_connection, tenant_id, provider, connection})
  end

  @doc """
  Removes an integration connection for a specific tenant and provider.
  """
  def remove_connection(tenant_id, provider) do
    GenServer.call(__MODULE__, {:remove_connection, tenant_id, provider})
  end

  @doc """
  Lists all connections for a specific tenant.
  """
  def list_connections(tenant_id) do
    GenServer.call(__MODULE__, {:list_connections, tenant_id})
  end

  # Server callbacks

  @impl true
  def init(state) do
    # Could load persisted connections from database here
    {:ok, state}
  end

  @impl true
  def handle_call({:get_connection, tenant_id, provider}, _from, state) do
    connection = get_in(state, [tenant_id, provider])
    {:reply, connection, state}
  end

  @impl true
  def handle_call({:register_connection, tenant_id, provider, connection}, _from, state) do
    tenant_connections = Map.get(state, tenant_id, %{})
    updated_tenant = Map.put(tenant_connections, provider, connection)
    updated_state = Map.put(state, tenant_id, updated_tenant)

    # Could persist to database here
    Logger.info("Registered #{provider} connection for tenant #{tenant_id}")

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:remove_connection, tenant_id, provider}, _from, state) do
    updated_state = case Map.get(state, tenant_id) do
      nil -> state
      tenant_connections ->
        updated_tenant = Map.delete(tenant_connections, provider)
        if map_size(updated_tenant) == 0 do
          Map.delete(state, tenant_id)
        else
          Map.put(state, tenant_id, updated_tenant)
        end
    end

    # Could update database here
    Logger.info("Removed #{provider} connection for tenant #{tenant_id}")

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:list_connections, tenant_id}, _from, state) do
    connections = Map.get(state, tenant_id, %{})
    {:reply, Map.keys(connections), state}
  end
end
