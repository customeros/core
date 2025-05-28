defmodule Core.Ai do
  require OpenTelemetry.Tracer
  alias Core.Ai.Anthropic
  alias Core.Ai.Gemini

  @anthropic_models [:claude_haiku, :claude_sonnet]
  @gemini_models [:gemini_pro, :gemini_flash]
  @supported_models @anthropic_models ++ @gemini_models

  # 90 seconds
  @default_timeout 90 * 1000

  @doc """
  Supervised AI request with timeout - convenience function
  """
  @spec ask_with_timeout(
          Ai.Request.t(),
          timeout()
        ) ::
          {:ok, String.t()} | {:error, any()}
  def ask_with_timeout(
        request,
        timeout \\ @default_timeout
      ) do
    OpenTelemetry.Tracer.with_span "ai.ask_with_timeout" do
      OpenTelemetry.Tracer.set_attributes([
        {"ai.model", request.model},
        {"ai.timeout_ms", timeout},
        {"ai.max_tokens", request.max_output_tokens},
        {"ai.temperature", request.model_temperature},
        {"ai.has_system_prompt", not is_nil(request.system_prompt)}
      ])

      task = ask_async(request)

      case Task.yield(task, timeout) do
        {:ok, result} ->
          OpenTelemetry.Tracer.set_status(:ok)
          result

        nil ->
          OpenTelemetry.Tracer.set_status(:error, "ai_request_timeout")
          Task.Supervisor.terminate_child(Core.Ai.Supervisor, task.pid)
          {:error, :ai_request_timeout}

        {:exit, reason} ->
          OpenTelemetry.Tracer.set_status(:error, "ai_request_failed")
          {:error, {:ai_request_failed, reason}}
      end
    end
  end

  @doc """
  Supervised async AI request - returns task for caller control
  """
  @spec ask_async(Ai.Request.t()) :: Task.t()
  def ask_async(request) do
    OpenTelemetry.Tracer.with_span "ai.ask_async" do
      OpenTelemetry.Tracer.set_attributes([
        {"ai.model", request.model},
        {"ai.max_tokens", request.max_output_tokens},
        {"ai.temperature", request.model_temperature},
        {"ai.has_system_prompt", not is_nil(request.system_prompt)}
      ])

      Task.Supervisor.async(Core.Ai.Supervisor, fn ->
        ask(request)
      end)
    end
  end

  # Private functions

  defp ask(request) when request.model in @anthropic_models do
    anthropic_request = %Anthropic.Request{
      model: request.model,
      prompt: request.prompt,
      system_prompt: request.system_prompt,
      max_output_tokens: request.max_output_tokens,
      model_temperature: request.model_temperature
    }

    Anthropic.Ask.ask(
      anthropic_request,
      Anthropic.Config.from_application_env()
    )
  end

  defp ask(request) when request.model in @gemini_models do
    gemini_request = %Gemini.Request{
      model: request.model,
      prompt: request.prompt,
      system_prompt: request.system_prompt,
      max_output_tokens: request.max_output_tokens,
      model_temperature: request.model_temperature
    }

    Gemini.Ask.ask(gemini_request, Gemini.Config.from_application_env())
  end

  defp ask(request) when request.prompt == "" or not is_binary(request.prompt),
    do: {:error, :invalid_prompt}

  defp ask(request)
       when request.model not in @supported_models do
    {:error, {:unsupported_model, request.model}}
  end

  defp ask(_) do
    {:error, {:invalid_request, "expected AskAIRequest struct"}}
  end
end
