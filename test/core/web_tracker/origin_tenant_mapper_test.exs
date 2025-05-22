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
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("malicious-site.com")
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("fake-kanda.com")
    end

    test "returns error for origins with protocols" do
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("https://getkanda.com")
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("http://dashboard.kanda.co.uk")
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("https://infinity.co")
    end

    test "returns error for origins with paths" do
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("getkanda.com/path")
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("infinity.co/dashboard")
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("nuso.cloud/app")
    end

    test "handles invalid input" do
      assert {:error, :invalid_origin} = OriginTenantMapper.get_tenant_for_origin(nil)
      assert {:error, :invalid_origin} = OriginTenantMapper.get_tenant_for_origin(123)
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("")
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin(" ")
    end

    test "handles subdomains correctly" do
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("blog.getkanda.com")
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("app.infinity.co")
      assert {:error, :origin_not_configured} = OriginTenantMapper.get_tenant_for_origin("dev.nuso.cloud")
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
      refute OriginTenantMapper.whitelisted?("malicious-site.com")
      refute OriginTenantMapper.whitelisted?("fake-kanda.com")
    end

    test "returns false for origins with protocols" do
      refute OriginTenantMapper.whitelisted?("https://getkanda.com")
      refute OriginTenantMapper.whitelisted?("http://dashboard.kanda.co.uk")
      refute OriginTenantMapper.whitelisted?("https://infinity.co")
    end

    test "returns false for origins with paths" do
      refute OriginTenantMapper.whitelisted?("getkanda.com/path")
      refute OriginTenantMapper.whitelisted?("infinity.co/dashboard")
      refute OriginTenantMapper.whitelisted?("nuso.cloud/app")
    end

    test "returns false for invalid input" do
      refute OriginTenantMapper.whitelisted?(nil)
      refute OriginTenantMapper.whitelisted?(123)
      refute OriginTenantMapper.whitelisted?("")
      refute OriginTenantMapper.whitelisted?(" ")
    end

    test "returns false for subdomains" do
      refute OriginTenantMapper.whitelisted?("blog.getkanda.com")
      refute OriginTenantMapper.whitelisted?("app.infinity.co")
      refute OriginTenantMapper.whitelisted?("dev.nuso.cloud")
    end
  end
end
