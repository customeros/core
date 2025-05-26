defmodule Core.Ai.Gemini.ApiRequest do
  @derive Jason.Encoder
  @moduledoc """
  The JSON structure for a Gemini API request.
  """

  @type t :: %__MODULE__{
          contents: [Content.t()],
          generationConfig: GenerationConfig.t() | nil
        }

  defstruct [:contents, :generationConfig]
end
