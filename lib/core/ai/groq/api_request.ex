defmodule Core.Ai.Groq.ApiRequest do
  @moduledoc """
  The JSON structure for a Groq API request.
  """
  @derive Jason.Encoder
  alias Core.Ai.Groq.Message

  @type t :: %__MODULE__{
          model: String.t(),
          messages: [Message.t()],
          max_tokens: integer() | nil,
          temperature: float() | nil
        }

  defstruct [
    :model,
    :messages,
    :max_tokens,
    :temperature
  ]
end
