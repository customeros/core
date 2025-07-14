defmodule Core.Ai.Request do
  @moduledoc """
  Represents a request to ask a question to an AI Model.
  """
  @default_model :gemini_flash_2_0
  @default_max_tokens 512
  @default_temperature 0.2
  @default_response_type :text

  @type model ::
          :claude_haiku_3_5
          | :claude_sonnet_4_0
          | :llama3_70b
          | :llama3_8b
          | :llama33_70b
          | :llama31_8b
          | :llama4_scout
          | :llama4_maverick
          | :gemma3_27b
          | :gemini_flash_2_0
          | :gemini_flash_2_5
          | :gemini_flash_light_2_5
          | :gemini_pro_2_5

  @type response_type :: :text | :json
  @type t :: %__MODULE__{
          model: model,
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
