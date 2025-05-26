defmodule Core.AI.Company.IndustryTest do
  use Core.DataCase
  import Mox

  alias Core.Crm.Companies.Enrichments.Industry

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    Application.put_env(:core, :anthropic_service, Core.External.Anthropic.Service.Mock)
    :ok
  end

  describe "company industry classification" do
    test "identify/1 with valid company data returns industry" do
      company_data = %{
        domain: "https://example.com",
        homepage_content: "Software company specializing in AI solutions"
      }

      Core.External.Anthropic.Service.Mock
      |> expect(:ask, fn _request, _config ->
        {:ok, "513210"}
      end)

      assert {:ok, industry} = Industry.identify(company_data)
      assert is_binary(industry)
      assert industry == "513210"
    end

    test "identify/1 with minimal data returns error" do
      company_data = %{
        domain: "https://example.com"
      }

      assert {:error, {:invalid_request, "Invalid input format"}} = Industry.identify(company_data)
    end

    test "identify/1 with invalid data returns error" do
      company_data = %{
        invalid: "data"
      }

      assert {:error, {:invalid_request, "Invalid input format"}} = Industry.identify(company_data)
    end

    test "identify/1 handles nil values gracefully" do
      company_data = nil

      assert {:error, {:invalid_request, "Input cannot be nil"}} = Industry.identify(company_data)
    end

    test "identify/1 handles API errors" do
      company_data = %{
        domain: "https://example.com",
        homepage_content: "Software company"
      }

      Core.External.Anthropic.Service.Mock
      |> expect(:ask, fn _request, _config ->
        {:error, {:api_error, "Rate limit exceeded"}}
      end)

      assert {:error, {:api_error, "Rate limit exceeded"}} = Industry.identify(company_data)
    end
  end
end
