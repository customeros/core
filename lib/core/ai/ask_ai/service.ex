defmodule Core.Ai.AskAi do
  @supported_models [:claude_haiku, :claude_sonnet]

  @type service :: module()
  @type config :: map()

  @spec ask(Core.Ai.AskAi.AskAIRequest.t(), service(), config()) :: {:ok, String.t()} | {:error, any()}
  def ask(request, service \\ default_service(), config \\ default_config())

  def ask(%Core.Ai.AskAi.AskAIRequest{model: model, prompt: prompt} = message, service, config)
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

  def ask(%Core.Ai.AskAi.AskAIRequest{prompt: prompt}, _service, _config)
      when not is_binary(prompt) or prompt == "" do
    {:error, {:invalid_request, "prompt must be a non-empty string"}}
  end

  def ask(%Core.Ai.AskAi.AskAIRequest{model: model}, _service, _config)
      when model not in @supported_models do
    {:error, {:unsupported_model, model}}
  end

  def ask(_, _service, _config) do
    {:error, {:invalid_request, "expected AskAIRequest struct"}}
  end

  # Private functions for default values
  defp default_service do
    Application.get_env(:core, :anthropic_service, Core.External.Anthropic.Service)
  end

  defp default_config do
    Core.External.Anthropic.Config.from_application_env()
  end
end
