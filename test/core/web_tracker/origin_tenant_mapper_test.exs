defmodule Core.WebTracker.OriginTenantMapperTest do
  use ExUnit.Case, async: true
  alias Core.WebTracker.OriginTenantMapper

  describe "get_tenant_for_origin/1" do
    test "returns tenant for whitelisted origin" do
      assert {:ok, "kandacouk"} = OriginTenantMapper.get_tenant_for_origin("getkanda.com")
      assert {:ok, "kandacouk"} = OriginTenantMapper.get_tenant_for_origin("dashboard.kanda.co.uk")
      assert {:ok, "infinityco"} = OriginTenantMapper.get_tenant_for_origin("infinity.co")
      assert {:ok, "nusocloud"} = OriginTenantMapper.get_tenant_for_origin("nuso.cloud")
      assert {:ok, "nusocloud"} = OriginTenantMapper.get_tenant_for_origin("nusocloud.eu")
    end

    test "returns error for non-whitelisted origin" do
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("unknown.domain.com")
    end

    test "returns error for origins with protocols" do
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("https://getkanda.com")
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("http://dashboard.kanda.co.uk")
    end

    test "returns error for origins with paths" do
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("getkanda.com/path")
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("infinity.co/dashboard")
    end

    test "handles invalid input" do
      assert {:error, :invalid_origin} = OriginTenantMapper.get_tenant_for_origin(nil)
      assert {:error, :invalid_origin} = OriginTenantMapper.get_tenant_for_origin(123)
    end
  end

  describe "whitelisted?/1" do
    test "returns true for whitelisted origins" do
      assert OriginTenantMapper.whitelisted?("getkanda.com")
      assert OriginTenantMapper.whitelisted?("dashboard.kanda.co.uk")
      assert OriginTenantMapper.whitelisted?("infinity.co")
      assert OriginTenantMapper.whitelisted?("nuso.cloud")
      assert OriginTenantMapper.whitelisted?("nusocloud.eu")
    end

    test "returns false for non-whitelisted origins" do
      refute OriginTenantMapper.whitelisted?("unknown.domain.com")
      refute OriginTenantMapper.whitelisted?("example.com")
      refute OriginTenantMapper.whitelisted?("https://getkanda.com")
      refute OriginTenantMapper.whitelisted?("getkanda.com/path")
    end

    test "returns false for invalid input" do
      refute OriginTenantMapper.whitelisted?(nil)
      refute OriginTenantMapper.whitelisted?(123)
    end
  end
end
