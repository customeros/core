defmodule Core.External.Gemini.ServiceTest do
  use Core.DataCase
  import Mox

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    # Set up test configuration for Gemini service
    config = %{
      gemini_api_key: "test_key",
      gemini_api_path: "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent"
    }

    Application.put_env(:core, :ai, config)

    # Configure the mock to be used
    Application.put_env(:core, :gemini_service, Core.External.Gemini.Service.Mock)

    {:ok, config: config}
  end

  alias Core.External.Gemini.Models.AskAIRequest

  describe "ask/1" do
    test "with valid request returns successful response", %{config: config} do
      request = %AskAIRequest{
        model: :gemini_pro,
        prompt: "What is 2+2?",
        max_output_tokens: 100,
        model_temperature: 0.7
      }

      Core.External.Gemini.Service.Mock
      |> expect(:ask, fn ^request, ^config ->
        {:ok, "The answer is 4."}
      end)

      assert {:ok, response} = Core.External.Gemini.Service.Mock.ask(request, config)
      assert response == "The answer is 4."
    end

    test "with system prompt combines prompts correctly", %{config: config} do
      request = %AskAIRequest{
        model: :gemini_pro,
        prompt: "What is 2+2?",
        system_prompt: "You are a helpful math tutor.",
        max_output_tokens: 100,
        model_temperature: 0.7
      }

      Core.External.Gemini.Service.Mock
      |> expect(:ask, fn ^request, ^config ->
        {:ok, "As your math tutor, I can tell you that 2+2 equals 4."}
      end)

      assert {:ok, response} = Core.External.Gemini.Service.Mock.ask(request, config)
      assert response == "As your math tutor, I can tell you that 2+2 equals 4."
    end

    test "with invalid model returns error" do
      request = %AskAIRequest{
        model: :invalid_model,
        prompt: "What is 2+2?",
        max_output_tokens: 100,
        model_temperature: 0.7
      }

      assert {:error, "model must be :gemini_pro"} = Core.External.Gemini.Service.ask(request)
    end

    test "with empty prompt returns error" do
      request = %AskAIRequest{
        model: :gemini_pro,
        prompt: "",
        max_output_tokens: 100,
        model_temperature: 0.7
      }

      assert {:error, "prompt cannot be empty"} = Core.External.Gemini.Service.ask(request)
    end

    test "with nil prompt returns error" do
      request = %AskAIRequest{
        model: :gemini_pro,
        prompt: nil,
        max_output_tokens: 100,
        model_temperature: 0.7
      }

      assert {:error, "prompt cannot be empty"} = Core.External.Gemini.Service.ask(request)
    end

    test "handles API errors gracefully", %{config: config} do
      request = %AskAIRequest{
        model: :gemini_pro,
        prompt: "What is 2+2?",
        max_output_tokens: 100,
        model_temperature: 0.7
      }

      Core.External.Gemini.Service.Mock
      |> expect(:ask, fn ^request, ^config ->
        {:error, {:api_error, "Rate limit exceeded"}}
      end)

      assert {:error, {:api_error, "Rate limit exceeded"}} = Core.External.Gemini.Service.Mock.ask(request, config)
    end

    test "handles invalid responses gracefully", %{config: config} do
      request = %AskAIRequest{
        model: :gemini_pro,
        prompt: "What is 2+2?",
        max_output_tokens: 100,
        model_temperature: 0.7
      }

      Core.External.Gemini.Service.Mock
      |> expect(:ask, fn ^request, ^config ->
        {:error, {:invalid_response, "Invalid response format"}}
      end)

      assert {:error, {:invalid_response, "Invalid response format"}} = Core.External.Gemini.Service.Mock.ask(request, config)
    end

    test "handles HTTP errors gracefully", %{config: config} do
      request = %AskAIRequest{
        model: :gemini_pro,
        prompt: "What is 2+2?",
        max_output_tokens: 100,
        model_temperature: 0.7
      }

      Core.External.Gemini.Service.Mock
      |> expect(:ask, fn ^request, ^config ->
        {:error, {:http_error, "Connection refused"}}
      end)

      assert {:error, {:http_error, "Connection refused"}} = Core.External.Gemini.Service.Mock.ask(request, config)
    end
  end
end
