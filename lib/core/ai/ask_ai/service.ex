defmodule Core.Ai.AskAi do
  @supported_models [:claude_haiku, :claude_sonnet]

  @spec ask(Core.Ai.AskAi.AskAIRequest.t()) :: {:ok, String.t()} | {:error, any()}

  def ask(%Core.Ai.AskAi.AskAIRequest{model: model, prompt: prompt} = message)
      when model in @supported_models and is_binary(prompt) and prompt != "" do
    anthropic_request = %Core.External.Anthropic.Models.AskAIRequest{
      model: message.model,
      prompt: message.prompt,
      system_prompt: message.system_prompt,
      max_output_tokens: message.max_output_tokens,
      model_temperature: message.model_temperature
    }

    Core.External.Anthropic.Service.ask(
      anthropic_request,
      Core.External.Anthropic.Config.from_application_env()
    )
  end

  def ask(%Core.Ai.AskAi.AskAIRequest{prompt: prompt})
      when not is_binary(prompt) or prompt == "" do
    {:error, {:invalid_request, "prompt must be a non-empty string"}}
  end

  def ask(%Core.Ai.AskAi.AskAIRequest{model: model})
      when model not in @supported_models do
    {:error, {:unsupported_model, model}}
  end

  def ask(_) do
    {:error, {:invalid_request, "expected AskAIRequest struct"}}
  end
end
