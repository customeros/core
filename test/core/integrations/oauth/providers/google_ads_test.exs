defmodule Core.Integrations.OAuth.Providers.GoogleAdsTest do
  use Core.DataCase, async: true

  alias Core.Integrations.OAuth.Providers.GoogleAds

  describe "authorize_url/2" do
    test "generates authorization URL with correct parameters" do
      tenant_id = "test_tenant_123"
      redirect_uri = "http://localhost:4000/google-ads/callback"

      # Mock the configuration
      config = %{
        auth_base_url: "https://accounts.google.com",
        client_id: "test_client_id",
        scopes: ["https://www.googleapis.com/auth/adwords"]
      }

      with_mocks([
        {Application, [], [get_env: fn :core, :google_ads -> config end]}
      ]) do
        {:ok, url} = GoogleAds.authorize_url(tenant_id, redirect_uri)

        assert String.contains?(
                 url,
                 "https://accounts.google.com/o/oauth2/auth"
               )

        assert String.contains?(url, "client_id=test_client_id")
        assert String.contains?(url, "redirect_uri=#{URI.encode(redirect_uri)}")

        assert String.contains?(
                 url,
                 "scope=#{URI.encode("https://www.googleapis.com/auth/adwords")}"
               )

        assert String.contains?(url, "response_type=code")
        assert String.contains?(url, "access_type=offline")
        assert String.contains?(url, "prompt=consent")
        assert String.contains?(url, "state=")
      end
    end

    test "raises error when auth_base_url is not configured" do
      tenant_id = "test_tenant_123"
      redirect_uri = "http://localhost:4000/google-ads/callback"

      with_mocks([
        {Application, [], [get_env: fn :core, :google_ads -> %{} end]}
      ]) do
        assert_raise RuntimeError,
                     ~r/Google Ads auth_base_url is not configured/,
                     fn ->
                       GoogleAds.authorize_url(tenant_id, redirect_uri)
                     end
      end
    end
  end

  describe "generate_state/1" do
    test "generates state with tenant_id" do
      tenant_id = "test_tenant_123"
      state = GoogleAds.generate_state(tenant_id)

      # State should be a hex string followed by underscore and tenant_id
      # 16 bytes = 32 hex chars + underscore + tenant_id
      assert String.length(state) > 32
      assert String.ends_with?(state, "_#{tenant_id}")
    end
  end
end
