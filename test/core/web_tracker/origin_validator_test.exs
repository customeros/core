defmodule Core.WebTracker.OriginValidatorTest do
  use ExUnit.Case, async: true
  alias Core.WebTracker.OriginValidator

  describe "should_ignore_origin?/1" do
    test "ignores HubSpot preview domains" do
      assert OriginValidator.should_ignore_origin?(
               "123456789.hubspotpreview-na1.com"
             )

      assert OriginValidator.should_ignore_origin?(
               "987654321.hubspotpreview-eu1.com"
             )

      assert OriginValidator.should_ignore_origin?(
               "111222333.hubspotpreview-asia1.com"
             )
    end

    test "does not ignore valid domains" do
      refute OriginValidator.should_ignore_origin?("getkanda.com")
      refute OriginValidator.should_ignore_origin?("dashboard.kanda.co.uk")
      refute OriginValidator.should_ignore_origin?("infinity.co")
      refute OriginValidator.should_ignore_origin?("nuso.cloud")
    end

    test "handles invalid input" do
      refute OriginValidator.should_ignore_origin?(nil)
      refute OriginValidator.should_ignore_origin?(123)
      refute OriginValidator.should_ignore_origin?("")
      refute OriginValidator.should_ignore_origin?(" ")
    end

    test "handles domains with subdomains" do
      refute OriginValidator.should_ignore_origin?("blog.getkanda.com")
      refute OriginValidator.should_ignore_origin?("app.dashboard.kanda.co.uk")
      refute OriginValidator.should_ignore_origin?("dev.infinity.co")
    end

    test "handles domains with protocols" do
      refute OriginValidator.should_ignore_origin?("https://getkanda.com")

      refute OriginValidator.should_ignore_origin?(
               "http://dashboard.kanda.co.uk"
             )
    end

    test "handles domains with paths" do
      refute OriginValidator.should_ignore_origin?("getkanda.com/path")

      refute OriginValidator.should_ignore_origin?(
               "dashboard.kanda.co.uk/dashboard"
             )
    end
  end
end
