defmodule Core.External.Gemini.Service do
  alias Core.External.Gemini.Models
  alias Core.External.Gemini.Config

  require Logger

  @behaviour Core.External.Gemini.Behaviour

  @api_key_param "key"
  @content_type_header "content-type"

  @impl true
  @spec ask(Models.AskAIRequest.t(), Config.t()) :: {:ok, String.t()} | {:error, any()}
  def ask(%Models.AskAIRequest{} = message, %Config{} = config) do
    with :ok <- Models.AskAIRequest.validate(message),
         :ok <- Config.validate(config),
         {:ok, req_body} <- build_request(message),
         {:ok, response} <- execute(req_body, config) do
      {:ok, response}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def ask(%Models.AskAIRequest{} = message) do
    ask(message, Config.from_application_env())
  end

  defp build_request(%Models.AskAIRequest{} = message) do
    prompt =
      if message.system_prompt && String.trim(message.system_prompt) != "" do
        """
        System: #{message.system_prompt}

        User: #{message.prompt}
        """
      else
        message.prompt
      end

    request = %Models.GeminiApiRequest{
      contents: [
        %Models.Content{
          role: "user",
          parts: [%Models.Part{text: prompt}]
        }
      ],
      generationConfig: %Models.GenerationConfig{
        temperature: message.model_temperature,
        maxOutputTokens: message.max_output_tokens
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
        {:error, {:http_error, "API request failed with status #{status}: #{body}"}}
    end
  end
end
