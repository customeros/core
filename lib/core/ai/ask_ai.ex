defmodule Core.Ai do
  @moduledoc """
  Provides a unified interface for AI model interactions across multiple providers.

  This module handles:
  - Multi-model AI request routing (Anthropic Claude, Google Gemini, and Groq)
  - Supervised and unsupervised AI requests
  - Request validation and model selection
  - Response handling and error management
  - OpenTelemetry tracing and monitoring
  - Model-specific configuration management

  The module supports multiple AI models:
  - Anthropic: Claude Haiku and Claude Sonnet
  - Google: Gemini Pro and Gemini Flash
  - Groq: LLaMA3 70B and other Groq models

  It implements proper AI integration practices including:
  - Request validation
  - Model selection
  - Error handling
  - Performance monitoring
  - Proper request routing
  - Configuration management
  """

  require OpenTelemetry.Tracer
  alias Core.Ai.Anthropic
  alias Core.Ai.Gemini
  alias Core.Ai.Groq
  alias Core.Ai.Request

  @anthropic_models [:claude_haiku_3_5, :claude_sonnet_4_0]
  @gemini_models [
    :gemma3_27b,
    :gemini_flash_2_0,
    :gemini_flash_2_5,
    :gemini_flash_light_2_5,
    :gemini_pro_2_5
  ]
  @groq_models [
    :llama4_maverick,
    :llama4_scout,
    :llama3_70b,
    :llama3_8b,
    :llama33_70b,
    :llama31_8b,
    :qwen_qwq32b
  ]
  @supported_models @anthropic_models ++ @gemini_models ++ @groq_models

  @doc """
  Supervised async AI request
  """
  @spec ask_supervised(Request.t()) :: Task.t()
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

  defp ask(%Request{} = request) when request.model in @anthropic_models do
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

  defp ask(%Request{} = request) when request.model in @gemini_models do
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
        model_temperature: request.model_temperature,
        response_type: request.response_type
      }

      Gemini.Ask.ask(gemini_request, Gemini.Config.from_application_env())
    end
  end

  defp ask(%Request{} = request) when request.model in @groq_models do
    OpenTelemetry.Tracer.with_span "ai.ask_groq" do
      OpenTelemetry.Tracer.set_attributes([
        {"ai.model", request.model},
        {"ai.max_tokens", request.max_output_tokens},
        {"ai.temperature", request.model_temperature},
        {"ai.has_system_prompt", not is_nil(request.system_prompt)}
      ])

      groq_request = %Groq.Request{
        model: request.model,
        prompt: request.prompt,
        system_prompt: request.system_prompt,
        max_output_tokens: request.max_output_tokens,
        model_temperature: request.model_temperature
      }

      Groq.Ask.ask(groq_request, Groq.Config.from_application_env())
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
