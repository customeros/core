defmodule Core.WebTracker.OriginTenantMapperTest do
  use ExUnit.Case, async: true
  alias Core.WebTracker.OriginTenantMapper

  describe "get_tenant_for_origin/1" do
    test "returns tenant for whitelisted origin" do
      assert {:ok, "getkandacom"} =
               OriginTenantMapper.get_tenant_for_origin("getkanda.com")

      assert {:ok, "getkandacom"} =
               OriginTenantMapper.get_tenant_for_origin("dashboard.kanda.co.uk")

      assert {:ok, "infinityco"} =
               OriginTenantMapper.get_tenant_for_origin("infinity.co")

      assert {:ok, "nusocloud"} =
               OriginTenantMapper.get_tenant_for_origin("nuso.cloud")

      assert {:ok, "nusocloud"} =
               OriginTenantMapper.get_tenant_for_origin("nusocloud.eu")
    end

    test "returns error for non-whitelisted origin" do
      assert {:error, :origin_not_configured} =
               OriginTenantMapper.get_tenant_for_origin("unknown.domain.com")

      assert {:error, :origin_not_configured} =
               OriginTenantMapper.get_tenant_for_origin("malicious-site.com")

      assert {:error, :origin_not_configured} =
               OriginTenantMapper.get_tenant_for_origin("fake-kanda.com")
    end

    test "returns ok for origins with protocols" do
      assert {:ok, "getkandacom"} =
               OriginTenantMapper.get_tenant_for_origin("https://getkanda.com")

      assert {:ok, "getkandacom"} =
               OriginTenantMapper.get_tenant_for_origin(
                 "http://dashboard.kanda.co.uk"
               )

      assert {:ok, "infinityco"} =
               OriginTenantMapper.get_tenant_for_origin("https://infinity.co")
    end

    test "extracts origin from path before validation" do
      assert {:ok, "getkandacom"} =
               OriginTenantMapper.get_tenant_for_origin("getkanda.com/path")

      assert {:ok, "infinityco"} =
               OriginTenantMapper.get_tenant_for_origin("infinity.co/dashboard")

      assert {:ok, "nusocloud"} =
               OriginTenantMapper.get_tenant_for_origin("nuso.cloud/app")
    end

    test "handles invalid input" do
      assert {:error, "origin not provided"} =
               OriginTenantMapper.get_tenant_for_origin(nil)

      assert {:error, "invalid origin"} =
               OriginTenantMapper.get_tenant_for_origin(123)

      assert {:error, "origin not provided"} =
               OriginTenantMapper.get_tenant_for_origin("")

      assert {:error, :origin_not_configured} =
               OriginTenantMapper.get_tenant_for_origin(" ")
    end

    test "handles subdomains correctly" do
      assert {:ok, "getkandacom"} =
               OriginTenantMapper.get_tenant_for_origin("blog.getkanda.com")

      assert {:ok, "infinityco"} =
               OriginTenantMapper.get_tenant_for_origin("app.infinity.co")

      assert {:ok, "nusocloud"} =
               OriginTenantMapper.get_tenant_for_origin("dev.nuso.cloud")
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

    test "returns true for origins with protocols" do
      assert OriginTenantMapper.whitelisted?("https://getkanda.com")
      assert OriginTenantMapper.whitelisted?("http://dashboard.kanda.co.uk")
      assert OriginTenantMapper.whitelisted?("https://infinity.co")
    end

    test "returns true for origins with paths" do
      assert OriginTenantMapper.whitelisted?("getkanda.com/path")
      assert OriginTenantMapper.whitelisted?("infinity.co/dashboard")
      assert OriginTenantMapper.whitelisted?("nuso.cloud/app")
    end

    test "returns false for invalid input" do
      refute OriginTenantMapper.whitelisted?(nil)
      refute OriginTenantMapper.whitelisted?(123)
      refute OriginTenantMapper.whitelisted?("")
      refute OriginTenantMapper.whitelisted?(" ")
    end

    test "returns true for subdomains" do
      assert OriginTenantMapper.whitelisted?("blog.getkanda.com")
      assert OriginTenantMapper.whitelisted?("app.infinity.co")
      assert OriginTenantMapper.whitelisted?("dev.nuso.cloud")
    end
  end
end
