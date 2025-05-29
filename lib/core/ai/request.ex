defmodule Core.Ai.Request do
  @derive Jason.Encoder
  @moduledoc """
  Represents a request to ask a question to an AI Model.
  """
  @default_model :claude_haiku
  @default_max_tokens 512
  @default_temperature 0.2

  @type model :: :claude_haiku | :claude_sonnet | :gemini_pro | :gemini_flash

  @type t :: %__MODULE__{
          model: model(),
          prompt: String.t(),
          system_prompt: String.t() | nil,
          max_output_tokens: integer() | nil,
          model_temperature: float() | nil
        }

  defstruct [
    :model,
    :prompt,
    :system_prompt,
    :max_output_tokens,
    :model_temperature
  ]

  @doc """
  Creates a new AI request with default settings
  """
  def new(prompt, opts \\ []) when is_binary(prompt) do
    %__MODULE__{
      model: opts[:model] || @default_model,
      prompt: prompt,
      system_prompt: opts[:system_prompt],
      max_output_tokens: opts[:max_tokens] || @default_max_tokens,
      model_temperature: opts[:temperature] || @default_temperature
    }
  end
end
