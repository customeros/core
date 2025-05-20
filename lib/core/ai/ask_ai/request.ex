defmodule Core.Ai.AskAi.AskAIRequest do
  @derive Jason.Encoder
  @moduledoc """
  Represents a request to ask a question to an AI Model.
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
    model_temperature: 0.2
  ]
end
