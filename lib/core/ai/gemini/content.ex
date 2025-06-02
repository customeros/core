defmodule Core.Ai.Gemini.Content do
  @moduledoc """
  Module defining the content structure for Gemini AI API interactions.

  This module defines the data structure used to format content for the
  Gemini AI API, including message roles and content parts. It supports
  both text and inline data (like images) in the conversation.
  """

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
