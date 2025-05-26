defmodule Core.AI.Company.LocationTest do
  @moduledoc """
  Tests for the Core.AI.Company.Location module.

  These tests verify that the location identification functionality:
  - Correctly identifies country codes from company data
  - Handles invalid inputs appropriately
  - Manages API errors gracefully
  """

  use Core.DataCase
  import Mox

  alias Core.Crm.Companies.Enrichments.Location
  alias Core.AITestHelper

  setup :verify_on_exit!
  setup do
    Core.AITestHelper.setup_ai_test()
  end

  describe "identifyCountryCodeA2/1" do
    test "returns country code for US company with valid input" do
      company_data = Core.AITestHelper.test_company_data().valid
      expected_code = "US"

      expect(Core.Ai.AskAi.Mock, :ask_with_timeout, fn _request ->
        {:ok, expected_code}
      end)

      assert {:ok, country_code} = Location.identifyCountryCodeA2(company_data)
      assert country_code == expected_code
    end

    test "returns country code for UK company with valid input" do
      company_data = Core.AITestHelper.test_company_data().valid
      expected_code = "GB"

      expect(Core.Ai.AskAi.Mock, :ask_with_timeout, fn _request ->
        {:ok, expected_code}
      end)

      assert {:ok, country_code} = Location.identifyCountryCodeA2(company_data)
      assert country_code == expected_code
    end

    test "returns error for empty content" do
      company_data = Core.AITestHelper.test_company_data().empty_content

      expect(Core.Ai.AskAi.Mock, :ask_with_timeout, fn _request ->
        Core.AITestHelper.error_responses().invalid_request
      end)

      assert {:error, reason} = Location.identifyCountryCodeA2(company_data)
      assert reason == {:invalid_request, "Invalid company data"}
    end

    test "returns error for nil content" do
      company_data = Core.AITestHelper.test_company_data().nil_content

      expect(Core.Ai.AskAi.Mock, :ask_with_timeout, fn _request ->
        {:error, {:invalid_request, "Invalid input format"}}
      end)

      assert {:error, reason} = Location.identifyCountryCodeA2(company_data)
      assert reason == {:invalid_request, "Invalid input format"}
    end

    test "handles API errors gracefully" do
      company_data = Core.AITestHelper.test_company_data().valid

      expect(Core.Ai.AskAi.Mock, :ask_with_timeout, fn _request ->
        Core.AITestHelper.error_responses().api_error
      end)

      assert {:error, reason} = Location.identifyCountryCodeA2(company_data)
      assert reason == "API error"
    end
  end
end
