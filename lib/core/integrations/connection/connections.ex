defmodule Core.Integrations.Connections do
  @moduledoc """
  Context module for managing integration connections.

  This module provides functions for managing connections to external integration
  providers (e.g., HubSpot) for tenants. It handles the creation, updating, and
  management of OAuth credentials and connection status.

  ## Examples

      # Get a connection
      {:ok, connection} = get_connection(tenant_id, :hubspot)

      # Create a new connection
      {:ok, connection} = create_connection(%{
        tenant_id: "tenant_123",
        provider: :hubspot,
        access_token: "token_123",
        token_type: "Bearer",
        expires_at: ~U[2024-12-31 23:59:59Z]
      })

      # Update connection status
      {:ok, connection} = update_status(connection, :active)

  """

  import Ecto.Query
  alias Core.Repo
  alias Core.Integrations.Connection

  @doc """
  Gets a connection for a tenant and provider.

  ## Examples

      iex> get_connection("tenant_123", :hubspot)
      {:ok, %Connection{}}

      iex> get_connection("tenant_123", :nonexistent)
      {:error, :not_found}
  """
  def get_connection(tenant_id, provider) when is_binary(tenant_id) do
    case Repo.get_by(Connection, tenant_id: tenant_id, provider: provider) do
      nil -> {:error, :not_found}
      connection -> {:ok, connection}
    end
  end

  def get_connection_by_id(id) do
    case Repo.get(Connection, id) do
      nil -> {:error, :not_found}
      connection -> {:ok, connection}
    end
  end

  @doc """
  Creates a new integration connection.

  ## Examples

      iex> create_connection(%{
      ...>   tenant_id: "tenant_123",
      ...>   provider: :hubspot,
      ...>   access_token: "token_123",
      ...>   token_type: "Bearer",
      ...>   expires_at: ~U[2024-12-31 23:59:59Z]
      ...> })
      {:ok, %Connection{}}

      iex> create_connection(%{tenant_id: "tenant_123"})
      {:error, %Ecto.Changeset{}}
  """
  def create_connection(attrs) do
    attrs =
      Map.put(
        attrs,
        :id,
        Core.Utils.IdGenerator.generate_id_16(Connection.id_prefix())
      )

    %Connection{}
    |> Connection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an integration connection.

  ## Examples

      iex> update_connection(connection, %{status: :active})
      {:ok, %Connection{}}

      iex> update_connection(connection, %{status: :invalid})
      {:error, %Ecto.Changeset{}}
  """
  def update_connection(%Connection{} = connection, attrs) do
    connection
    |> Connection.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the status of a connection.

  ## Examples

      iex> update_status(connection, :active)
      {:ok, %Connection{}}

      iex> update_status(connection, :invalid)
      {:error, %Ecto.Changeset{}}
  """
  def update_status(%Connection{} = connection, status) do
    update_connection(connection, %{status: status})
  end

  @doc """
  Deletes a connection.

  ## Examples

      iex> delete_connection(connection)
      {:ok, %Connection{}}

      iex> delete_connection(connection)
      {:error, %Ecto.Changeset{}}
  """
  def delete_connection(%Connection{} = connection) do
    Repo.delete(connection)
  end

  @doc """
  Lists all connections for a tenant.

  ## Examples

      iex> list_connections("tenant_123")
      [%Connection{}, ...]
  """
  def list_connections(tenant_id) when is_binary(tenant_id) do
    Connection
    |> where([c], c.tenant_id == ^tenant_id)
    |> Repo.all()
  end

  @doc """
  Lists all active connections for a tenant.

  ## Examples

      iex> list_active_connections("tenant_123")
      [%Connection{}, ...]
  """
  def list_active_connections(tenant_id) when is_binary(tenant_id) do
    Connection
    |> where([c], c.tenant_id == ^tenant_id and c.status == :active)
    |> Repo.all()
  end

  @doc """
  Lists all connections that need token refresh.

  ## Examples

      iex> list_connections_needing_refresh()
      [%Connection{}, ...]
  """
  def list_connections_needing_refresh do
    now = DateTime.utc_now()
    # 1 hour before expiry
    refresh_threshold = DateTime.add(now, 3600)

    Connection
    |> where([c], c.status == :active and c.expires_at <= ^refresh_threshold)
    |> Repo.all()
  end

  @doc """
  Gets a connection by provider and external_system_id.

  ## Examples
      iex> get_connection_by_provider_and_external_id(:hubspot, "146363387")
      {:ok, %Connection{}}

      iex> get_connection_by_provider_and_external_id(:hubspot, "nonexistent")
      {:error, :not_found}
  """
  def get_connection_by_provider_and_external_id(provider, external_system_id) do
    case Repo.get_by(Connection,
           provider: provider,
           external_system_id: external_system_id
         ) do
      nil -> {:error, :not_found}
      connection -> {:ok, connection}
    end
  end
end
