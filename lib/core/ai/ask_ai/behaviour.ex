defmodule Core.Ai.AskAi.Behaviour do
  @moduledoc """
  Behaviour module defining the contract for AI service interactions.

  This module defines the interface for making AI requests, with support for both
  synchronous and asynchronous operations. It handles various AI models and provides
  consistent error handling across different implementations.
  """

  alias Core.Ai.AskAi.AskAIRequest

  @type naics_code :: String.t()
  @type model :: :google_gemini_pro | :anthropic_claude_3_sonnet
  @type config :: %{
    api_key: String.t(),
    api_path: String.t(),
    timeout: integer()
  }

  # Error reasons grouped by category
  @type validation_error :: :invalid_request | :unsupported_model
  @type request_error :: :json_encode_error | :http_error | :invalid_response
  @type service_error :: :api_error | :timeout
  @type error_reason :: validation_error() | request_error() | service_error()
  @type error :: {error_reason(), String.t() | term()}

  @doc """
  Makes an AI request with timeout handling.

  ## Parameters
    - request: The AskAIRequest struct containing the request details
    - config: Configuration map for the AI service

  ## Returns
    - `{:ok, String.t()}` - Successful response with the AI's output
    - `{:error, error()}` - Error tuple with reason

  ## Examples
      iex> request = %AskAIRequest{model: :claude_sonnet, prompt: "Hello"}
      iex> config = %{api_key: "key", timeout: 5000}
      iex> Core.Ai.AskAi.ask(request, config)
      {:ok, "AI response"}
  """
  @callback ask(AskAIRequest.t(), config()) :: {:ok, String.t()} | {:error, error()}

  @doc """
  Makes an AI request with built-in timeout handling.

  This is a convenience function that wraps `ask/2` with timeout handling.
  The timeout is configured in the application environment.

  ## Parameters
    - request: The AskAIRequest struct containing the request details

  ## Returns
    - `{:ok, String.t()}` - Successful response with the AI's output
    - `{:error, error()}` - Error tuple with reason

  ## Examples
      iex> request = %AskAIRequest{model: :claude_sonnet, prompt: "Hello"}
      iex> Core.Ai.AskAi.ask_with_timeout(request)
      {:ok, "AI response"}
  """
  @callback ask_with_timeout(AskAIRequest.t()) :: {:ok, String.t()} | {:error, error()}
end
