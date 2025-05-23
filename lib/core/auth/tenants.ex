defmodule Core.Auth.Tenants do
  @moduledoc """
  The Tenants context.
  """

  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Auth.Tenants.Tenant

  ## Database getters

  def get_tenant_by_name(name) when is_binary(name) do
    Repo.get_by(Tenant, name: name)
  end

  def get_tenant_by_id(tenant_id) when is_binary(tenant_id) do
    Repo.get_by(Tenant, id: tenant_id)
  end

  ## Tenant registration

  def create_tenant(name) when is_binary(name) do
    %Tenant{}
    |> Tenant.changeset(%{name: name, domain: "#{name}.com"})
    |> Repo.insert()
  end

  def create_tenant(%{name: name, domain: domain}) do
    %Tenant{}
    |> Tenant.changeset(%{name: name, domain: domain})
    |> Repo.insert()
  end

  def create_tenant_and_return_id(name) do
    case create_tenant(name) do
      {:ok, tenant} -> {:ok, tenant.id}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def create_tenant_and_build_icp(name) do
    case create_tenant_and_return_id(name) do
      {:ok, tenant_id} ->
        tenant_id
        |> Core.Icp.Service.create_icp_for_tenant()

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
