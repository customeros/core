defmodule Core.Crm.LeadsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Core.Crm.Leads` context.
  """

  @doc """
  Generate a lead.
  """
  def lead_fixture(attrs \\ %{}) do
    tenant = "test_tenant"
    ref_id = "test_#{System.unique_integer()}"

    # Create tenant first
    {:ok, _tenant} = Core.Auth.Tenants.create_tenant(tenant)

    {:ok, lead} =
      Core.Crm.Leads.get_or_create(
        tenant,
        attrs
        |> Enum.into(%{
          ref_id: ref_id,
          type: :contact
        })
      )

    lead
  end
end
