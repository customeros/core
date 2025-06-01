defmodule Core.Ai.Gemini.ApiRequest do
  @moduledoc """
  The JSON structure for a Gemini API request.
  """
  @derive Jason.Encoder
  alias Core.Ai.Gemini.Content
  alias Core.Ai.Gemini.GenerationConfig

  @type t :: %__MODULE__{
          contents: [Content.t()],
          generationConfig: GenerationConfig.t() | nil
        }

  defstruct [:contents, :generationConfig]
end
