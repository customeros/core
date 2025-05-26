defmodule Core.AI.Company.NameTest do
  @moduledoc """
  Tests for the Core.AI.Company.Name module.

  These tests verify that the company name identification functionality:
  - Correctly identifies company names from various data sources
  - Handles invalid inputs appropriately
  - Manages API errors gracefully
  """

  use Core.DataCase
  import Mox

  alias Core.Crm.Companies.Enrichments.Name
  alias Core.AITestHelper

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    Core.AITestHelper.setup_ai_test()
  end

  describe "identify/1" do
    test "with valid company data returns name" do
      company_data = Core.AITestHelper.test_company_data().valid
      expected_name = "Test Company"

      expect(Core.Ai.AskAi.Mock, :ask_with_timeout, fn _request ->
        {:ok, expected_name}
      end)

      assert {:ok, name} = Name.identify(company_data)
      assert name == expected_name
    end

    test "with website only returns name" do
      company_data = %{
        domain: "testcompany.com",
        homepage_content: nil
      }
      expected_name = "Test Company"

      expect(Core.Ai.AskAi.Mock, :ask_with_timeout, fn _request ->
        {:ok, expected_name}
      end)

      assert {:ok, name} = Name.identify(company_data)
      assert name == expected_name
    end

    test "with invalid data returns error" do
      company_data = Core.AITestHelper.test_company_data().empty_content

      expect(Core.Ai.AskAi.Mock, :ask_with_timeout, fn _request ->
        Core.AITestHelper.error_responses().invalid_request
      end)

      assert {:error, reason} = Name.identify(company_data)
      assert reason == {:invalid_request, "Invalid company data"}
    end

    test "handles nil values gracefully" do
      company_data = Core.AITestHelper.test_company_data().nil_content

      expect(Core.Ai.AskAi.Mock, :ask_with_timeout, fn _request ->
        Core.AITestHelper.error_responses().invalid_request
      end)

      assert {:error, reason} = Name.identify(company_data)
      assert reason == {:invalid_request, "Invalid company data"}
    end

    test "handles API errors" do
      company_data = Core.AITestHelper.test_company_data().valid

      expect(Core.Ai.AskAi.Mock, :ask_with_timeout, fn _request ->
        Core.AITestHelper.error_responses().api_error
      end)

      assert {:error, reason} = Name.identify(company_data)
      assert reason == "API error"
    end
  end
end
