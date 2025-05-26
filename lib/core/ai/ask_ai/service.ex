defmodule Core.Ai.AskAi do
  @supported_models [:claude_haiku, :claude_sonnet]
  @type service :: module()
  @type config :: map()
  # 90 seconds
  @default_timeout 90 * 1000

  @doc """
  Supervised async AI request - returns task for caller control
  """
  @spec ask_async(Core.Ai.AskAi.AskAIRequest.t(), service(), config()) ::
          Task.t()
  def ask_async(
        request,
        service \\ default_service(),
        config \\ default_config()
      ) do
    Task.Supervisor.async(Core.Ai.AskAi.Supervisor, fn ->
      ask(request, service, config)
    end)
  end

  @doc """
  Supervised AI request with timeout - convenience function
  """
  @spec ask_with_timeout(
          Core.Ai.AskAi.AskAIRequest.t(),
          service(),
          config(),
          timeout()
        ) ::
          {:ok, String.t()} | {:error, any()}
  def ask_with_timeout(
        request,
        service \\ default_service(),
        config \\ default_config(),
        timeout \\ @default_timeout
      ) do
    task = ask_async(request, service, config)

    case Task.yield(task, timeout) do
      {:ok, result} ->
        result

      nil ->
        Task.Supervisor.terminate_child(Core.Ai.TaskSupervisor, task.pid)
        {:error, :ai_request_timeout}

      {:exit, reason} ->
        {:error, {:ai_request_failed, reason}}
    end
  end

  defp ask(request, service, config)

  defp ask(
         %Core.Ai.AskAi.AskAIRequest{model: model, prompt: prompt} = message,
         service,
         config
       )
       when model in @supported_models and is_binary(prompt) and prompt != "" do
    anthropic_request = %Core.External.Anthropic.Models.AskAIRequest{
      model: message.model,
      prompt: message.prompt,
      system_prompt: message.system_prompt,
      max_output_tokens: message.max_output_tokens,
      model_temperature: message.model_temperature
    }

    service.ask(anthropic_request, config)
  end

  defp ask(%Core.Ai.AskAi.AskAIRequest{prompt: prompt}, _service, _config)
       when not is_binary(prompt) or prompt == "" do
    {:error, {:invalid_request, "prompt must be a non-empty string"}}
  end

  defp ask(%Core.Ai.AskAi.AskAIRequest{model: model}, _service, _config)
       when model not in @supported_models do
    {:error, {:unsupported_model, model}}
  end

  defp ask(_, _service, _config) do
    {:error, {:invalid_request, "expected AskAIRequest struct"}}
  end

  # Private functions for default values
  defp default_service do
    Application.get_env(
      :core,
      :anthropic_service,
      Core.External.Anthropic.Service
    )
  end

  defp default_config do
    Core.External.Anthropic.Config.from_application_env()
  end
end
