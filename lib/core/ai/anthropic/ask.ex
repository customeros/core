defmodule Core.Ai.Anthropic.Ask do
  @moduledoc """
  Provides integration with Anthropic's Claude AI API for text generation and analysis.

  This module handles:
  - Claude API request construction and execution
  - Response parsing and validation
  - Error handling and retry logic
  - Request configuration management
  - System and user prompt handling
  - Response format standardization

  The module supports multiple Claude models:
  - Claude 3.5 Haiku (2024-10-22)
  - Claude 3.5 Sonnet (2024-10-22)

  It implements proper API integration practices including:
  - Secure API key handling
  - Request validation
  - Response parsing
  - Error handling
  - Timeout management
  - Content type handling
  - Version management
  """

  alias Core.Ai.Anthropic.ApiRequest
  alias Core.Ai.Anthropic.Message
  alias Core.Ai.Anthropic.Request
  alias Core.Ai.Anthropic.Config

  require Logger

  @api_key_header "x-api-key"
  @anthropic_api_header "anthropic-version"
  @content_type_header "content-type"
  @default_api_version "2023-06-01"

  @haiku_version "claude-3-5-haiku-20241022"
  @sonnet_version "claude-3-5-sonnet-20241022"

  @spec ask(Request.t(), Config.t()) ::
          {:ok, String.t()} | {:error, any()}
  def ask(%Request{} = message, %Config{} = config) do
    with :ok <- Request.validate(message),
         :ok <- Config.validate(config),
         {:ok, req_body} <- build_request(message),
         {:ok, response} <- execute(req_body, config) do
      {:ok, response}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_request(%Request{} = message) do
    model_name =
      case message.model do
        :claude_haiku -> @haiku_version
        :claude_sonnet -> @sonnet_version
      end

    request = %ApiRequest{
      model: model_name,
      messages: [%Message{role: "user", content: message.prompt}],
      max_tokens: message.max_output_tokens,
      temperature: message.model_temperature
    }

    request =
      if message.system_prompt && String.trim(message.system_prompt) != "" do
        %{request | system: message.system_prompt}
      else
        request
      end

    {:ok, request}
  end

  defp execute(req_body, config) do
    req_body
    |> Jason.encode()
    |> case do
      {:ok, json_body} ->
        config.api_path
        |> build_request_with_headers(json_body, config)
        |> send_request(config.timeout)

      {:error, reason} ->
        {:error, {:json_encode_error, reason}}
    end
  end

  defp build_request_with_headers(url, body, config) do
    headers = [
      {@content_type_header, "application/json"},
      {@api_key_header, config.api_key},
      {@anthropic_api_header, @default_api_version}
    ]

    Finch.build(:post, url, headers, body)
  end

  defp send_request(request, timeout) do
    request
    |> Finch.request(Core.Finch, receive_timeout: timeout)
    |> case do
      {:ok, response} -> process_response(response.status, response.body)
      {:error, reason} -> {:error, {:http_error, reason}}
    end
  end

  defp process_response(status, body) when status in 200..299 do
    with {:ok, decoded} <- Jason.decode(body),
         content when is_list(content) <- Map.get(decoded, "content"),
         %{"type" => "text", "text" => text} <-
           Enum.find(content, &(Map.get(&1, "type") == "text")) do
      {:ok, String.trim(text)}
    else
      nil -> {:error, {:invalid_response, "No text content found in response"}}
      _ -> {:error, {:invalid_response, "Invalid response format"}}
    end
  end

  defp process_response(status, body) do
    body
    |> Jason.decode(keys: :atoms)
    |> case do
      {:ok, %{error: %{type: type, message: message}}} ->
        {:error, {:api_error, "#{type}: #{message}"}}

      _ ->
        {:error,
         {:http_error, "API request failed with status #{status}: #{body}"}}
    end
  end
end
