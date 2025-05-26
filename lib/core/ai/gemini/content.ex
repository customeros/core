defmodule Core.Ai.Gemini.Content do
  @derive Jason.Encoder
  @moduledoc """
  A single content in a conversation.
  """

  @type t :: %__MODULE__{
          role: String.t(),
          parts: [Part.t()]
        }

  defstruct [:role, :parts]

  defmodule Part do
    @derive Jason.Encoder
    @moduledoc """
    A part of the content (text in our case).
    """

    @type t :: %__MODULE__{
            text: String.t()
          }

    defstruct [:text]
  end
end
