defmodule Core.Ai.Groq.Request do
  @derive Jason.Encoder
  @moduledoc """
  Represents a request to ask a question to Groq AI.
  """

  @type model :: :llama3_70b | :llama3_8b | :llama33_70b | :llama31_8b | :gemma2_9b

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
      request.model not in [:llama3_70b, :llama3_8b, :llama33_70b, :llama31_8b, :gemma2_9b] ->
        {:error, "model must be one of: :llama3_70b, :llama3_8b, :llama33_70b, :llama31_8b, or :gemma2_9b"}

      is_nil(request.prompt) or request.prompt == "" ->
        {:error, "prompt cannot be empty"}

      true ->
        :ok
    end
  end
end
