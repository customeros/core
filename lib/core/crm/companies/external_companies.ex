defmodule Core.Crm.Companies.ExternalCompanies do
  @moduledoc """
  Manages external company mappings and operations.

  This module handles the mapping between companies in external systems
  (e.g., HubSpot) and companies in our system. It provides functions for:
  * Creating and updating external company records
  * Retrieving external companies by various criteria
  * Managing the synchronization state of external companies
  * Handling webhook data from external providers

  ## Usage

  ```elixir
  # Get an external company
  external_company = Core.Crm.Companies.ExternalCompanies.get_by_external_id(tenant_id, :hubspot, "123")

  # Create a new external company
  {:ok, external_company} = Core.Crm.Companies.ExternalCompanies.create(%{
    tenant_id: tenant_id,
    name: "Example Corp",
    external_id: "123",
    provider: :hubspot,
    data: %{...}
  })

  # Update an external company
  {:ok, updated} = Core.Crm.Companies.ExternalCompanies.update(external_company, %{
    name: "Updated Corp",
    data: %{...}
  })
  ```
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Ecto.Repo
  alias Core.Crm.Companies.ExternalCompany
  alias Core.Repo
  alias Core.Utils.IdGenerator
  import Ecto.Query

  @doc """
  Gets an external company by its external ID and provider.
  """
  def get_by_external_id(tenant_id, provider, external_id) do
    query = from ec in ExternalCompany,
      join: ic in assoc(ec, :integration_connection),
      where: ic.tenant_id == ^tenant_id and
             ic.provider == ^provider and
             ec.external_id == ^external_id

    case Repo.one(query) do
      nil -> nil
      external_company -> external_company
    end
  end

  @doc """
  Creates a new external company record.
  """
  def create(attrs) do
    external_company = %ExternalCompany{
      id: IdGenerator.generate_id_21(ExternalCompany.id_prefix()),
      last_synced_at: DateTime.utc_now()
    }

    external_company
    |> ExternalCompany.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing external company record.
  """
  def update(%ExternalCompany{} = external_company, attrs) do
    attrs = Map.put(attrs, :last_synced_at, DateTime.utc_now())

    external_company
    |> ExternalCompany.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an external company record by its external ID.
  """
  def delete_by_external_id(tenant_id, provider, external_id) do
    query = from ec in ExternalCompany,
      join: ic in assoc(ec, :integration_connection),
      where: ic.tenant_id == ^tenant_id and
             ic.provider == ^provider and
             ec.external_id == ^external_id

    case Repo.one(query) do
      nil -> {:error, :not_found}
      external_company -> Repo.delete(external_company)
    end
  end

  @doc """
  Lists all external companies for a tenant and provider.
  """
  def list_by_tenant_and_provider(tenant_id, provider) do
    query = from ec in ExternalCompany,
      join: ic in assoc(ec, :integration_connection),
      where: ic.tenant_id == ^tenant_id and
             ic.provider == ^provider,
      order_by: [desc: ec.last_synced_at]

    {:ok, Repo.all(query)}
  end

  @doc """
  Gets an external company by its internal company ID.
  """
  def get_by_company_id(tenant_id, provider, company_id) do
    query = from ec in ExternalCompany,
      join: ic in assoc(ec, :integration_connection),
      where: ic.tenant_id == ^tenant_id and
             ic.provider == ^provider and
             ec.company_id == ^company_id

    case Repo.one(query) do
      nil -> {:error, :not_found}
      external_company -> {:ok, external_company}
    end
  end
end
