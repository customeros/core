defmodule Core.AITestHelper do
  @moduledoc """
  Helper module for AI-related tests.

  This module provides common setup functions, types, and constants
  used across AI-related tests. It helps maintain consistency and
  reduces duplication in test files.
  """

  @doc """
  Common setup for AI tests.

  This function:
  1. Configures the AI service mock
  2. Sets up verification on exit
  3. Returns a map of common test data

  ## Usage
      setup do
        Core.AITestHelper.setup_ai_test()
      end
  """
  def setup_ai_test do
    import Mox
    verify_on_exit!()
    Application.put_env(:core, :ai_service, Core.Ai.AskAi.Mock)
    {:ok, %{}}
  end

  @doc """
  NAICS (North American Industry Classification System) codes used in tests.

  These are valid 2022 NAICS codes that represent different industries:
  - 511210: Software Publishers
  - 513210: Software Development
  - 541512: Computer Systems Design Services
  - 518210: Data Processing, Hosting, and Related Services
  - 541715: Research and Development in the Physical, Engineering, and Life Sciences
  """
  def naics_codes do
    %{
      software_publisher: "511210",
      software_development: "513210",
      tech_consulting: "541512",
      data_processing: "518210",
      r_and_d: "541715"
    }
  end

  @doc """
  Common test data for company information.

  Returns a map of test data that can be used across different tests.
  """
  def test_company_data do
    %{
      valid: %{
        domain: "example.com",
        homepage_content: "TechCorp is a leading technology company"
      },
      empty_content: %{
        domain: "example.com",
        homepage_content: ""
      },
      nil_content: %{
        domain: "example.com",
        homepage_content: nil
      }
    }
  end

  @doc """
  Common error responses for AI service mocks.

  Returns a map of error responses that can be used in test expectations.
  """
  def error_responses do
    %{
      invalid_request: {:error, {:invalid_request, "Invalid company data"}},
      api_error: {:error, "API error"},
      timeout: {:error, {:timeout, "Request timed out"}},
      invalid_response: {:error, {:invalid_response, "Invalid response format"}}
    }
  end
end
