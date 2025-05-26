defmodule Core.Ai.Anthropic.Request do
  @derive Jason.Encoder
  @moduledoc """
  Represents a request to ask a question to Claude.
  """

  @type model :: :claude_haiku | :claude_sonnet

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
      request.model not in [:claude_haiku, :claude_sonnet] ->
        {:error, "model must be :claude_haiku or :claude_sonnet"}

      is_nil(request.prompt) or request.prompt == "" ->
        {:error, "prompt cannot be empty"}

      true ->
        :ok
    end
  end
end
