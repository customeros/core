defmodule Core.Ai.Gemini.Request do
  @derive Jason.Encoder
  @moduledoc """
  Represents a request to ask a question to Gemini.
  """

  @type model :: :gemini_pro | :gemini_flash

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
    max_output_tokens: 1024,
    model_temperature: 0.7
  ]

  @doc """
  Validates the request and returns errors if any.
  """
  def validate(%__MODULE__{} = request) do
    cond do
      request.model != :gemini_pro ->
        {:error, "model must be :gemini_pro or :gemini_flash"}

      is_nil(request.prompt) or request.prompt == "" ->
        {:error, "prompt cannot be empty"}

      true ->
        :ok
    end
  end
end
