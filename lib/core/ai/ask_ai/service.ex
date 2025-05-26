defmodule Core.Ai.AskAi do
  @moduledoc """
  Service module for making AI requests to various providers.

  This module provides a unified interface for making AI requests to different
  providers (Anthropic, Gemini, etc.) with consistent error handling and timeout
  management. It supports both synchronous and asynchronous operations.
  """

  @behaviour Core.Ai.AskAi.Behaviour

  alias Core.Ai.AskAi.AskAIRequest
  alias Core.External.Anthropic.Service, as: AnthropicService
  alias Core.External.Gemini.Service, as: GeminiService

  @default_timeout 90 * 1000

  @supported_models [:google_gemini_pro, :anthropic_claude_3_sonnet]

  @type model :: :google_gemini_pro | :anthropic_claude_3_sonnet
  @type config :: %{
    api_key: String.t(),
    api_path: String.t(),
    timeout: integer()
  }

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
  @impl true
  def ask(%AskAIRequest{} = request, config) do
    with :ok <- validate_request(request),
         :ok <- validate_config(config),
         {:ok, service} <- get_service(request.model),
         {:ok, provider_request} <- convert_request(request),
         {:ok, provider_config} <- convert_config(request.model, config) do
      # Wrap the service call in a Task with timeout
      task = Task.async(fn -> service.ask(provider_request, provider_config) end)

      try do
        case Task.await(task, config.timeout) do
          {:ok, response} -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end
      rescue
        Task.TimeoutError ->
          Task.shutdown(task)
          {:error, {:timeout, "Request timed out after #{config.timeout}ms"}}
        e in RuntimeError ->
          Task.shutdown(task)
          {:error, {:service_error, e.message}}
      end
    end
  end

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
  @impl true
  def ask_with_timeout(%AskAIRequest{} = request) do
    with {:ok, config} <- get_config(request.model),
         :ok <- validate_config(config),
         {:ok, response} <- ask(request, config) do
      {:ok, response}
    end
  end

  # Private functions

  defp validate_request(%AskAIRequest{model: model, prompt: prompt}) do
    cond do
      model not in @supported_models ->
        {:error, {:unsupported_model, "Model '#{model}' is not supported. Supported models are: #{Enum.join(@supported_models, ", ")}"}}
      not is_binary(prompt) or prompt == "" ->
        {:error, {:invalid_request, "Prompt must be a non-empty string"}}
      true ->
        :ok
    end
  end

  defp validate_config(%{api_key: key, timeout: timeout}) when is_binary(key) and is_integer(timeout) do
    :ok
  end
  defp validate_config(%{api_key: nil, timeout: _}), do: {:error, {:invalid_request, "API key is not set"}}
  defp validate_config(%{api_key: "", timeout: _}), do: {:error, {:invalid_request, "API key is not set"}}
  defp validate_config(%{api_key: _, timeout: nil}), do: {:error, {:invalid_request, "Timeout is not set"}}
  defp validate_config(%{api_key: _, timeout: timeout}) when not is_integer(timeout), do: {:error, {:invalid_request, "Timeout must be an integer"}}
  defp validate_config(_), do: {:error, {:invalid_request, "Configuration must include api_key (string) and timeout (integer)"}}

  defp get_service(:google_gemini_pro), do: {:ok, GeminiService}
  defp get_service(:anthropic_claude_3_sonnet), do: {:ok, AnthropicService}
  defp get_service(model), do: {:error, {:unsupported_model, "Model '#{model}' is not supported. Supported models are: #{Enum.join(@supported_models, ", ")}"}}

  defp get_config(model) do
    api_key = get_api_key(model)
    api_path = get_api_path(model)

    case {api_key, api_path} do
      {nil, _} -> {:error, {:invalid_request, "#{model} API key is not configured"}}
      {"", _} -> {:error, {:invalid_request, "#{model} API key is not configured"}}
      {_, nil} -> {:error, {:invalid_request, "#{model} API path is not configured"}}
      {_, ""} -> {:error, {:invalid_request, "#{model} API path is not configured"}}
      {key, path} -> {:ok, %{api_key: key, api_path: path, timeout: @default_timeout}}
    end
  end

  defp get_api_key(model) do
    case model do
      :google_gemini_pro -> Application.get_env(:core, :ai)[:gemini_api_key]
      :anthropic_claude_3_sonnet -> Application.get_env(:core, :ai)[:anthropic_api_key]
    end
  end

  defp get_api_path(model) do
    case model do
      :google_gemini_pro -> Application.get_env(:core, :ai)[:gemini_api_path]
      :anthropic_claude_3_sonnet -> Application.get_env(:core, :ai)[:anthropic_api_path]
    end
  end

  defp convert_request(%AskAIRequest{model: :google_gemini_pro} = request) do
    {:ok, %Core.External.Gemini.Models.AskAIRequest{
      model: :google_gemini_pro,
      prompt: request.prompt,
      system_prompt: request.system_prompt,
      max_output_tokens: request.max_output_tokens,
      model_temperature: request.model_temperature
    }}
  end
  defp convert_request(%AskAIRequest{model: :anthropic_claude_3_sonnet} = request) do
    {:ok, %Core.External.Anthropic.Models.AskAIRequest{
      model: :anthropic_claude_3_sonnet,
      prompt: request.prompt,
      system_prompt: request.system_prompt,
      max_output_tokens: request.max_output_tokens,
      model_temperature: request.model_temperature
    }}
  end

  defp convert_config(:google_gemini_pro, config) do
    {:ok, %Core.External.Gemini.Config{
      api_key: config.api_key,
      api_path: config.api_path,
      timeout: config.timeout
    }}
  end
  defp convert_config(:anthropic_claude_3_sonnet, config) do
    {:ok, %Core.External.Anthropic.Config{
      api_key: config.api_key,
      api_path: config.api_path,
      timeout: config.timeout
    }}
  end
end
