defmodule Core.Ai.Gemini.GenerationConfig do
  @moduledoc """
  Configuration for text generation.
  """
  @derive Jason.Encoder

  @json "application/json"
  @text "text/plain"

  # Could be more specific if needed
  @type mime_type :: String.t()
  @type t :: %__MODULE__{
          temperature: float() | nil,
          maxOutputTokens: integer() | nil,
          responseMimeType: mime_type() | nil
        }

  defstruct [:temperature, :maxOutputTokens, :responseMimeType]

  def json_response, do: @json
  def text_response, do: @text
end
