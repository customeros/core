defmodule Core.Ai.Gemini.Request do
  @moduledoc """
  Represents a request to ask a question to Gemini.
  """
  @type model ::
          :gemma3_27b
          | :gemini_flash_2_0
          | :gemini_flash_2_5
          | :gemini_flash_light_2_5
          | :gemini_pro_2_5
  @type response_type :: :text | :json

  @type t :: %__MODULE__{
          model: model(),
          prompt: String.t(),
          system_prompt: String.t() | nil,
          max_output_tokens: integer() | nil,
          model_temperature: float() | nil,
          response_type: response_type
        }

  defstruct [
    :model,
    :prompt,
    :system_prompt,
    :response_type,
    max_output_tokens: 1024,
    model_temperature: 0.7
  ]

  def validate(%__MODULE__{} = request) do
    cond do
      request.model not in [
        :gemma3_27b,
        :gemini_flash_2_0,
        :gemini_flash_2_5,
        :gemini_flash_light_2_5,
        :gemini_pro_2_5
      ] ->
        {:error, "model must be :gemini_pro or :gemini_flash"}

      is_nil(request.prompt) or request.prompt == "" ->
        {:error, "prompt cannot be empty"}

      true ->
        :ok
    end
  end
end
