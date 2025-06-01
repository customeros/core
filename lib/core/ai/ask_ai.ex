defmodule Core.Ai do
  require OpenTelemetry.Tracer
  alias Core.Ai.Anthropic
  alias Core.Ai.Gemini

  @anthropic_models [:claude_haiku, :claude_sonnet]
  @gemini_models [:gemini_pro, :gemini_flash]
  @supported_models @anthropic_models ++ @gemini_models

  @doc """
  Supervised async AI request 
  """
  @spec ask_supervised(Ai.Request.t()) :: Task.t()
  def ask_supervised(request) do
    OpenTelemetry.Tracer.with_span "ai.ask_supervised" do
      ctx = OpenTelemetry.Ctx.get_current()

      Task.Supervisor.async(Core.TaskSupervisor, fn ->
        OpenTelemetry.Ctx.attach(ctx)
        ask(request)
      end)
    end
  end

  # Private functions

  defp ask(request) when request.model in @anthropic_models do
    OpenTelemetry.Tracer.with_span "ai.ask_anthropic" do
      OpenTelemetry.Tracer.set_attributes([
        {"ai.model", request.model},
        {"ai.max_tokens", request.max_output_tokens},
        {"ai.temperature", request.model_temperature},
        {"ai.has_system_prompt", not is_nil(request.system_prompt)}
      ])

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
  end

  defp ask(request) when request.model in @gemini_models do
    OpenTelemetry.Tracer.with_span "ai.ask_gemini" do
      OpenTelemetry.Tracer.set_attributes([
        {"ai.model", request.model},
        {"ai.max_tokens", request.max_output_tokens},
        {"ai.temperature", request.model_temperature},
        {"ai.has_system_prompt", not is_nil(request.system_prompt)}
      ])

      gemini_request = %Gemini.Request{
        model: request.model,
        prompt: request.prompt,
        system_prompt: request.system_prompt,
        max_output_tokens: request.max_output_tokens,
        model_temperature: request.model_temperature
      }

      Gemini.Ask.ask(gemini_request, Gemini.Config.from_application_env())
    end
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
