defmodule Core.Ai.Groq.Message do
  @derive Jason.Encoder
  @moduledoc """
  A single message in a conversation.
  """

  @type t :: %__MODULE__{
          role: String.t(),
          content: String.t() | map()
        }

  defstruct [:role, :content]
end
