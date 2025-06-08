defmodule Core.Ai.Groq.Ask do
  @moduledoc """
  Provides integration with Groq AI API for text generation and analysis.

  This module handles:
  - Groq API request construction and execution
  - Response parsing and validation
  - Error handling and retry logic
  - Request configuration management
  - System and user prompt handling
  - Response format standardization

  The module supports the following Groq production models:
  - LLaMA3 70B (8192 context)
  - LLaMA3 8B (8192 context)
  - LLaMA 3.3 70B Versatile (128K context)
  - LLaMA 3.1 8B Instant (128K context)
  - Gemma 2 9B (8192 context)

  It implements proper API integration practices including:
  - Secure API key handling
  - Request validation
  - Response parsing
  - Error handling
  - Timeout management
  - Content type handling
  """

  alias Core.Ai.Groq.{ApiRequest, Message, Request, Config}

  require Logger

  @api_key_header "authorization"
  @content_type_header "content-type"

  # Current production model names
  @llama3_70b_model "llama3-70b-8192"
  @llama3_8b_model "llama3-8b-8192"
  @llama33_70b_model "llama-3.3-70b-versatile"
  @llama31_8b_model "llama-3.1-8b-instant"
  @gemma2_9b_model "gemma2-9b-it"

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
        :llama3_70b -> @llama3_70b_model
        :llama3_8b -> @llama3_8b_model
        :llama33_70b -> @llama33_70b_model
        :llama31_8b -> @llama31_8b_model
        :gemma2_9b -> @gemma2_9b_model
      end

    messages =
      if message.system_prompt && String.trim(message.system_prompt) != "" do
        [
          %Message{role: "system", content: message.system_prompt},
          %Message{role: "user", content: message.prompt}
        ]
      else
        [%Message{role: "user", content: message.prompt}]
      end

    request = %ApiRequest{
      model: model_name,
      messages: messages,
      max_tokens: message.max_output_tokens,
      temperature: message.model_temperature
    }

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
      {@api_key_header, "Bearer #{config.api_key}"}
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
         %{"choices" => [%{"message" => %{"content" => content}} | _]} <- decoded do
      {:ok, String.trim(content)}
    else
      _ -> {:error, {:invalid_response, "Invalid response format"}}
    end
  end

  defp process_response(status, body) do
    body
    |> Jason.decode(keys: :atoms)
    |> case do
      {:ok, %{error: %{message: message}}} ->
        {:error, {:api_error, message}}

      _ ->
        {:error,
         {:http_error, "API request failed with status #{status}: #{body}"}}
    end
  end
end
