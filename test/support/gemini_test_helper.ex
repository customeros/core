defmodule Core.External.Gemini.TestHelper do
  @moduledoc """
  Helper module for testing Gemini API integration.
  Provides test data and helper functions for Gemini tests.

  ## Usage

      # In your test file
      use Core.DataCase
      import Core.External.Gemini.TestHelper

      test "asks question successfully" do
        request = valid_request()
        config = test_config()

        assert {:ok, _response} = Service.ask(request, config)
      end
  """

  alias Core.External.Gemini.Models

  @doc """
  Returns a valid test request for Gemini tests.
  """
  def valid_request do
    %Models.AskAIRequest{
      model: :google_gemini_pro,
      prompt: "What is 2+2?",
      max_output_tokens: 100,
      model_temperature: 0.7
    }
  end

  @doc """
  Returns a valid test response for Gemini tests.
  """
  def valid_response do
    Jason.encode!(%{
      "candidates" => [
        %{
          "content" => %{
            "parts" => [
              %{
                "text" => "The answer is 4."
              }
            ]
          }
        }
      ]
    })
  end

  @doc """
  Returns an error response for Gemini tests.
  """
  def error_response do
    Jason.encode!(%{
      "error" => %{
        "code" => 400,
        "message" => "Invalid request",
        "status" => "INVALID_ARGUMENT"
      }
    })
  end

  @doc """
  Returns a test configuration for Gemini tests.
  """
  def test_config do
    %Core.External.Gemini.Config{
      api_path: "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent",
      api_key: "test-key",
      timeout: 45_000
    }
  end

  @doc """
  Returns a request with a system prompt for testing.
  """
  def request_with_system_prompt do
    %Models.AskAIRequest{
      model: :google_gemini_pro,
      prompt: "What is 2+2?",
      system_prompt: "You are a helpful math tutor.",
      max_output_tokens: 100,
      model_temperature: 0.7
    }
  end

  @doc """
  Returns a response with a system prompt for testing.
  """
  def response_with_system_prompt do
    Jason.encode!(%{
      "candidates" => [
        %{
          "content" => %{
            "parts" => [
              %{
                "text" => "As your math tutor, I can tell you that 2+2 equals 4."
              }
            ]
          }
        }
      ]
    })
  end
end
