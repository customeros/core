defmodule Core.AI.Company.NameTest do
  use Core.DataCase
  import Mox

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    # Set up test configuration for Anthropic service
    Application.put_env(:core, :anthropic, %{
      anthropic_api_key: "test_key",
      anthropic_api_path: "https://api.anthropic.com/v1/"
    })

    # Configure the mock to be used
    Application.put_env(:core, :anthropic_service, Core.External.Anthropic.Service.Mock)

    :ok
  end

  alias Core.Crm.Companies.Enrichments.Name

  describe "identify/1" do
    test "with valid company data returns name" do
      company_data = %{
        domain: "example.com",
        homepage_content: "TechCorp is a leading technology company"
      }

      Core.External.Anthropic.Service.Mock
      |> expect(:ask, fn _prompt, _config ->
        {:ok, "TechCorp"}
      end)

      assert {:ok, name} = Name.identify(company_data)
      assert name == "TechCorp"
    end

    test "with website only returns name" do
      company_data = %{
        domain: "example.com",
        homepage_content: "Welcome to our website"
      }

      Core.External.Anthropic.Service.Mock
      |> expect(:ask, fn _prompt, _config ->
        {:ok, "Example Corp"}
      end)

      assert {:ok, name} = Name.identify(company_data)
      assert name == "Example Corp"
    end

    test "with invalid data returns error" do
      company_data = %{
        domain: "example.com",
        homepage_content: ""
      }

      Core.External.Anthropic.Service.Mock
      |> expect(:ask, fn _prompt, _config ->
        {:error, {:invalid_request, "Invalid company data"}}
      end)

      assert {:error, reason} = Name.identify(company_data)
      assert reason == {:invalid_request, "Invalid company data"}
    end

    test "handles nil values gracefully" do
      company_data = %{
        domain: "example.com",
        homepage_content: nil
      }

      Core.External.Anthropic.Service.Mock
      |> expect(:ask, fn _prompt, _config ->
        {:error, {:invalid_request, "Invalid company data"}}
      end)

      assert {:error, reason} = Name.identify(company_data)
      assert reason == {:invalid_request, "Invalid company data"}
    end

    test "handles API errors" do
      company_data = %{
        domain: "example.com",
        homepage_content: "TechCorp is a leading technology company"
      }

      Core.External.Anthropic.Service.Mock
      |> expect(:ask, fn _prompt, _config ->
        {:error, "API error"}
      end)

      assert {:error, reason} = Name.identify(company_data)
      assert reason == "API error"
    end
  end
end
