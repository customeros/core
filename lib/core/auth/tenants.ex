defmodule Core.Auth.Tenants do
  @moduledoc """
  The Tenants context.
  """

  import Ecto.Query, warn: false
  require Logger
  alias Core.Repo
  alias Core.Auth.Tenants.Tenant
  alias Core.Notifications.Slack

  ## Database getters

  def get_tenant_by_name(name) when is_binary(name) do
    case Repo.get_by(Tenant, name: name) do
      %Tenant{} = tenant -> {:ok, tenant}
      nil -> {:error, :not_found}
    end
  end

  def get_tenant_by_id(tenant_id) when is_binary(tenant_id) do
    case Repo.get_by(Tenant, id: tenant_id) do
      %Tenant{} = tenant -> {:ok, tenant}
      nil -> {:error, :not_found}
    end
  end

  ## Tenant registration

  def create_tenant(name, domain) do
    case %Tenant{}
         |> Tenant.changeset(%{name: name, domain: domain})
         |> Repo.insert() do
      {:ok, tenant} = result ->
        # Notify Slack about new tenant
        Task.start(fn ->
          case Slack.notify_new_tenant(tenant.name, tenant.domain) do
            :ok -> :ok
            {:error, reason} ->
              Logger.error("Failed to send Slack notification for tenant #{tenant.name} creation: #{inspect(reason)}")
          end
        end)
        result

      error ->
        error
    end
  end

  def create_tenant_and_return_id(name, domain) do
    case create_tenant(name, domain) do
      {:ok, tenant} -> {:ok, tenant.id}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def create_tenant_and_build_icp(name, domain) do
    case create_tenant_and_return_id(name, domain) do
      {:ok, tenant_id} ->
        tenant_id
        |> Core.Research.Orchestrator.create_icp_for_tenant()

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
