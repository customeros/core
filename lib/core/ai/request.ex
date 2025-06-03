defmodule Core.Ai.Request do
  @moduledoc """
  Represents a request to ask a question to an AI Model.
  """
  @default_model :claude_haiku
  @default_max_tokens 512
  @default_temperature 0.2
  @default_response_type :text

  @type model :: :claude_haiku | :claude_sonnet | :gemini_pro | :gemini_flash
  @type response_type :: :text | :json
  @type t :: %__MODULE__{
          model: model(),
          prompt: String.t(),
          system_prompt: String.t() | nil,
          max_output_tokens: integer() | nil,
          model_temperature: float() | nil,
          response_type: response_type() | nil
        }

  defstruct [
    :model,
    :prompt,
    :system_prompt,
    :max_output_tokens,
    :model_temperature,
    :response_type
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
      model_temperature: opts[:temperature] || @default_temperature,
      response_type: opts[:response_type] || @default_response_type
    }
  end
end
