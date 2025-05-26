defmodule Core.External.Gemini.ServicePropertyTest do
  use Core.DataCase

  alias Core.External.Gemini.Models

  test "handles various prompt lengths" do
    # Test short prompt
    short_request = %Models.AskAIRequest{
      model: :google_gemini_pro,
      prompt: "Short",
      model_temperature: 0.7
    }
    assert :ok = Models.AskAIRequest.validate(short_request)

    # Test long prompt
    long_request = %Models.AskAIRequest{
      model: :google_gemini_pro,
      prompt: String.duplicate("a", 1000),
      model_temperature: 0.7
    }
    assert :ok = Models.AskAIRequest.validate(long_request)
  end

  test "validates temperature values" do
    # Valid temperatures
    valid_request = %Models.AskAIRequest{
      model: :google_gemini_pro,
      prompt: "Test prompt",
      model_temperature: 0.7
    }
    assert :ok = Models.AskAIRequest.validate(valid_request)

    # Invalid temperatures
    invalid_requests = [
      %{valid_request | model_temperature: -0.1},
      %{valid_request | model_temperature: 1.1}
    ]

    for request <- invalid_requests do
      assert {:error, _} = Models.AskAIRequest.validate(request)
    end
  end

  test "validates token limits" do
    # Valid token limits
    valid_request = %Models.AskAIRequest{
      model: :google_gemini_pro,
      prompt: "Test prompt",
      max_output_tokens: 1000
    }
    assert :ok = Models.AskAIRequest.validate(valid_request)

    # Invalid token limits
    invalid_requests = [
      %{valid_request | max_output_tokens: 0},
      %{valid_request | max_output_tokens: 2049}
    ]

    for request <- invalid_requests do
      assert {:error, _} = Models.AskAIRequest.validate(request)
    end
  end
end
