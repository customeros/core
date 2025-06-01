defmodule Core.Crm.Leads.LeadTest do
  use Core.DataCase

  alias Core.Crm.Leads.Lead

  describe "lead" do
    alias Core.Crm.Leads.Lead

    import Core.Crm.LeadsFixtures

    test "list_by_tenant_id/1 returns all leads for tenant" do
      lead = lead_fixture()

      assert {:ok, [found_lead]} =
               Core.Crm.Leads.list_by_tenant_id(lead.tenant_id)

      assert found_lead.id == lead.id
    end

    test "changeset/2 returns a lead changeset" do
      lead = lead_fixture()
      assert %Ecto.Changeset{} = Lead.changeset(lead, %{})
    end

    test "get_or_create/2 with valid data creates a lead" do
      tenant = "test_tenant"

      valid_attrs = %{
        ref_id: "test_#{System.unique_integer()}",
        type: :contact
      }

      # Create tenant first
      {:ok, tenant_record} = Core.Auth.Tenants.create_tenant(tenant, "test.com")

      assert {:ok, %Lead{} = lead} =
               Core.Crm.Leads.get_or_create(tenant, valid_attrs)

      assert lead.ref_id == valid_attrs.ref_id
      assert lead.type == :contact
      assert lead.tenant_id == tenant_record.id
      assert lead.stage == :pending
    end

    test "get_or_create/2 with invalid data returns error changeset" do
      assert {:error, :not_found, "Tenant not found"} =
               Core.Crm.Leads.get_or_create("invalid_tenant", %{})
    end

    test "get_by_ref_id/2 returns the lead with given ref_id" do
      lead = lead_fixture()

      assert {:ok, found_lead} =
               Core.Crm.Leads.get_by_ref_id(lead.tenant_id, lead.ref_id)

      assert found_lead.id == lead.id
    end
  end
end
