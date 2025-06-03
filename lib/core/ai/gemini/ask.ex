defmodule Core.Ai.Gemini.Ask do
  @moduledoc """
  Provides integration with Google's Gemini AI API for text generation and analysis.

  This module handles:
  - Gemini API request construction and execution
  - Response parsing and validation
  - Error handling and retry logic
  - Request configuration management
  - System and user prompt handling
  - Response format standardization

  The module implements proper API integration practices including:
  - Secure API key handling
  - Request validation
  - Response parsing
  - Error handling
  - Timeout management
  - Content type handling
  """

  alias Core.Ai.Gemini

  require Logger

  @api_key_param "key"
  @content_type_header "content-type"

  def ask(%Gemini.Request{} = message, %Gemini.Config{} = config) do
    with :ok <- Gemini.Request.validate(message),
         :ok <- Gemini.Config.validate(config),
         {:ok, req_body} <- build_request(message),
         {:ok, response} <- execute(req_body, config) do
      {:ok, response}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def ask(%Gemini.Request{} = message) do
    ask(message, Gemini.Config.from_application_env())
  end

  defp build_request(%Gemini.Request{} = message) do
    response_mime =
      case message.response_type do
        :json -> "application/json"
        _ -> "text/plain"
      end

    prompt =
      case message.system_prompt do
        nil ->
          message.prompt

        "" ->
          message.prompt

        system_prompt when is_binary(system_prompt) ->
          if String.trim(system_prompt) != "" do
            """
            System: #{system_prompt}
            User: #{message.prompt}
            """
          else
            message.prompt
          end
      end

    request = %Gemini.ApiRequest{
      contents: [
        %Gemini.Content{
          role: "user",
          parts: [%{text: prompt}]
        }
      ],
      generationConfig: %Gemini.GenerationConfig{
        temperature: message.model_temperature,
        maxOutputTokens: message.max_output_tokens,
        responseMimeType: response_mime
      }
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
    url = "#{url}?#{@api_key_param}=#{config.api_key}"
    headers = [{@content_type_header, "application/json"}]
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
         [candidate | _] <- Map.get(decoded, "candidates", []),
         content <- Map.get(candidate, "content"),
         [part | _] <- Map.get(content, "parts", []),
         text <- Map.get(part, "text") do
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
      {:ok, %{error: %{message: message}}} ->
        {:error, {:api_error, message}}

      _ ->
        {:error,
         {:http_error, "API request failed with status #{status}: #{body}"}}
    end
  end
end
