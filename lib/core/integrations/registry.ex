defmodule Core.Integrations.Registry do
  @moduledoc """
  Registry for managing tenant-specific integrations.

  This module provides a facade for managing integration connections, handling:
  - Registration and management of integration connections
  - Provider type conversion (atoms to strings and vice versa)
  - Connection status management
  - Error handling and validation
  - Future extensibility for caching and connection pooling

  ## Usage

  ```elixir
  # Get a connection
  {:ok, connection} = Registry.get_connection(tenant_id, :hubspot)
  nil = Registry.get_connection(tenant_id, :nonexistent)

  # Register a connection
  {:ok, connection} = Registry.register_connection(tenant_id, :hubspot, credentials)
  {:error, reason} = Registry.register_connection(tenant_id, :invalid, credentials)

  # Update a connection
  {:ok, connection} = Registry.update_connection(tenant_id, :hubspot, %{status: "active"})
  {:error, reason} = Registry.update_connection(tenant_id, :hubspot, %{status: "invalid"})

  # List connections
  {:ok, connections} = Registry.list_connections(tenant_id)
  ```

  ## Connection Status

  Connections can have the following statuses:
  - `"active"` - Connection is active and ready to use
  - `"inactive"` - Connection is temporarily disabled
  - `"error"` - Connection has encountered an error and needs attention
  """

  use GenServer
  require Logger

  alias Core.Integrations.IntegrationConnections
  alias Core.Integrations.IntegrationConnection

  # Client API

  @doc """
  Gets a connection for a tenant and provider.
  Returns {:ok, connection} if found, nil if not found.
  """
  def get_connection(tenant_id, provider) when is_atom(provider) do
    GenServer.call(__MODULE__, {:get_connection, tenant_id, provider})
  end

  @doc """
  Registers a new connection for a tenant and provider.
  Returns {:ok, connection} on success, {:error, reason} on failure.
  """
  def register_connection(tenant_id, provider, credentials) when is_atom(provider) do
    GenServer.call(__MODULE__, {:register_connection, tenant_id, provider, credentials})
  end

  @doc """
  Updates an existing connection.
  Returns {:ok, connection} on success, {:error, reason} on failure.
  """
  def update_connection(tenant_id, provider, attrs) when is_atom(provider) do
    GenServer.call(__MODULE__, {:update_connection, tenant_id, provider, attrs})
  end

  @doc """
  Updates the status of a connection.
  Returns {:ok, connection} on success, {:error, reason} on failure.
  """
  def update_connection_status(tenant_id, provider, status) when is_atom(provider) do
    GenServer.call(__MODULE__, {:update_status, tenant_id, provider, status})
  end

  @doc """
  Updates the last sync timestamp for a connection.
  Returns {:ok, connection} on success, {:error, reason} on failure.
  """
  def update_last_sync(tenant_id, provider) when is_atom(provider) do
    GenServer.call(__MODULE__, {:update_last_sync, tenant_id, provider})
  end

  @doc """
  Removes a connection for a tenant and provider.
  Returns :ok on success, {:error, reason} on failure.
  """
  def remove_connection(tenant_id, provider) when is_atom(provider) do
    GenServer.call(__MODULE__, {:remove_connection, tenant_id, provider})
  end

  @doc """
  Lists all connections for a tenant.
  Returns {:ok, connections} on success, {:error, reason} on failure.
  """
  def list_connections(tenant_id) do
    GenServer.call(__MODULE__, {:list_connections, tenant_id})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get_connection, tenant_id, provider}, _from, state) do
    case IntegrationConnections.get_connection(tenant_id, Atom.to_string(provider)) do
      nil -> {:reply, nil, state}
      {:ok, connection} -> {:reply, {:ok, connection}, state}
    end
  end

  @impl true
  def handle_call({:register_connection, tenant_id, provider, credentials}, _from, state) do
    case IntegrationConnections.create_connection(tenant_id, Atom.to_string(provider), credentials) do
      {:ok, connection} -> {:reply, {:ok, connection}, state}
      {:error, changeset} -> {:reply, {:error, format_changeset_errors(changeset)}, state}
    end
  end

  @impl true
  def handle_call({:update_connection, tenant_id, provider, attrs}, _from, state) do
    case IntegrationConnections.update_connection(tenant_id, Atom.to_string(provider), attrs) do
      {:ok, connection} -> {:reply, {:ok, connection}, state}
      {:error, :not_found} -> {:reply, {:error, :not_found}, state}
      {:error, changeset} -> {:reply, {:error, format_changeset_errors(changeset)}, state}
    end
  end

  @impl true
  def handle_call({:update_status, tenant_id, provider, status}, _from, state) do
    case IntegrationConnections.update_status(tenant_id, Atom.to_string(provider), status) do
      {:ok, connection} -> {:reply, {:ok, connection}, state}
      {:error, :not_found} -> {:reply, {:error, :not_found}, state}
      {:error, :invalid_status} -> {:reply, {:error, :invalid_status}, state}
      {:error, changeset} -> {:reply, {:error, format_changeset_errors(changeset)}, state}
    end
  end

  @impl true
  def handle_call({:update_last_sync, tenant_id, provider}, _from, state) do
    case IntegrationConnections.update_last_sync(tenant_id, Atom.to_string(provider)) do
      {:ok, connection} -> {:reply, {:ok, connection}, state}
      {:error, :not_found} -> {:reply, {:error, :not_found}, state}
      {:error, changeset} -> {:reply, {:error, format_changeset_errors(changeset)}, state}
    end
  end

  @impl true
  def handle_call({:remove_connection, tenant_id, provider}, _from, state) do
    case IntegrationConnections.delete_connection(tenant_id, Atom.to_string(provider)) do
      {:ok, _} -> {:reply, :ok, state}
      {:error, :not_found} -> {:reply, {:error, :not_found}, state}
      {:error, changeset} -> {:reply, {:error, format_changeset_errors(changeset)}, state}
    end
  end

  @impl true
  def handle_call({:list_connections, tenant_id}, _from, state) do
    case IntegrationConnections.list_connections(tenant_id) do
      {:ok, connections} -> {:reply, {:ok, connections}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  # Private Functions

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
