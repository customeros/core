defmodule Core.Ai.Gemini.Content do
  @derive Jason.Encoder

  @type t :: %__MODULE__{
          role: String.t(),
          parts: [part()]
        }

  @type part ::
          %{text: String.t()}
          | %{inline_data: %{mime_type: String.t(), data: String.t()}}
          | map()

  defstruct [:role, :parts]
end
