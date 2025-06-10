defmodule Core.Ai.Groq.TestGroq do
  @moduledoc """
  A simple module to test the Groq API integration.
  This module provides a test function that can be called from IEx.
  """

  alias Core.Ai.Groq.{Ask, Request, Config}

  @doc """
  Tests the Groq API integration with a simple prompt.
  This function uses hardcoded values for testing purposes.

  ## Examples

      iex> Core.Ai.Groq.TestGroq.test_api()
      {:ok, "Response from Groq..."}

  """
  def test_api do
    # Create a test request with hardcoded values
    request = %Request{
      # Using LLaMA3 70B as it's a production model
      model: :llama3_70b,
      prompt: "Explain what Elixir is in one sentence.",
      system_prompt:
        "You are a helpful AI assistant that provides concise, accurate responses.",
      # Keep it short for testing
      max_output_tokens: 256,
      model_temperature: 0.7
    }

    # Get config from application environment
    config = Config.from_application_env()

    # Make the API call
    case Ask.ask(request, config) do
      {:ok, response} ->
        IO.puts("\n=== Groq API Test Response ===")
        IO.puts(response)
        IO.puts("=============================\n")
        {:ok, response}

      {:error, reason} ->
        IO.puts("\n=== Groq API Test Error ===")
        IO.puts("Error: #{inspect(reason)}")
        IO.puts("===========================\n")
        {:error, reason}
    end
  end

  @doc """
  Tests the Groq API integration with a custom prompt.
  This allows testing with different prompts while keeping other parameters constant.

  ## Examples

      iex> Core.Ai.Groq.TestGroq.test_api_with_prompt("What is Phoenix Framework?")
      {:ok, "Response from Groq..."}

  """
  def test_api_with_prompt(prompt) when is_binary(prompt) do
    request = %Request{
      # Using LLaMA3 70B as it's a production model
      model: :llama3_70b,
      prompt: prompt,
      system_prompt:
        "You are a helpful AI assistant that provides concise, accurate responses.",
      max_output_tokens: 256,
      model_temperature: 0.5
    }

    config = Config.from_application_env()

    case Ask.ask(request, config) do
      {:ok, response} ->
        IO.puts("\n=== Groq API Test Response ===")
        IO.puts(response)
        IO.puts("=============================\n")
        {:ok, response}

      {:error, reason} ->
        IO.puts("\n=== Groq API Test Error ===")
        IO.puts("Error: #{inspect(reason)}")
        IO.puts("===========================\n")
        {:error, reason}
    end
  end
end
