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

  ## Tenant registration

  def create_tenant(name) do
    %Tenant{}
    |> Tenant.changeset(%{name: name})
    |> Repo.insert()
  end
end
