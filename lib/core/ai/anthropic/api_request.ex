defmodule Core.Ai.Anthropic.ApiRequest do
  @derive Jason.Encoder
  @moduledoc """
  The JSON structure for a Claude API request.
  """

  @type t :: %__MODULE__{
          model: String.t(),
          system: String.t() | nil,
          messages: [Message.t()],
          max_tokens: integer() | nil,
          temperature: float() | nil
        }

  defstruct [:model, :system, :messages, :max_tokens, :temperature]
end
