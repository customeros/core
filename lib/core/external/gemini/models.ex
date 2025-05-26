defmodule Core.External.Gemini.Models do
  @moduledoc """
  Structs for representing Gemini API requests and responses.
  """

  defmodule AskAIRequest do
    @derive Jason.Encoder
    @moduledoc """
    Represents a request to ask a question to Gemini.
    """

    @type model :: :gemini_pro

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
      model_temperature: 0.7
    ]

    @doc """
    Validates the request and returns errors if any.
    """
    def validate(%__MODULE__{} = request) do
      cond do
        request.model != :gemini_pro ->
          {:error, "model must be :gemini_pro"}

        is_nil(request.prompt) or request.prompt == "" ->
          {:error, "prompt cannot be empty"}

        true ->
          :ok
      end
    end
  end

  defmodule GeminiApiRequest do
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

  defmodule Content do
    @derive Jason.Encoder
    @moduledoc """
    A single content in a conversation.
    """

    @type t :: %__MODULE__{
            role: String.t(),
            parts: [Part.t()]
          }

    defstruct [:role, :parts]
  end

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

  defmodule GenerationConfig do
    @derive Jason.Encoder
    @moduledoc """
    Configuration for text generation.
    """

    @type t :: %__MODULE__{
            temperature: float() | nil,
            maxOutputTokens: integer() | nil
          }

    defstruct [:temperature, :maxOutputTokens]
  end

  defmodule GeminiApiResponse do
    @derive Jason.Encoder
    @moduledoc """
    The JSON structure for a Gemini API response.
    """

    @type t :: %__MODULE__{
            candidates: [Candidate.t()]
          }

    defstruct [:candidates]
  end

  defmodule Candidate do
    @derive Jason.Encoder
    @moduledoc """
    A response candidate from Gemini.
    """

    @type t :: %__MODULE__{
            content: Content.t(),
            finishReason: String.t() | nil,
            safetyRatings: [SafetyRating.t()]
          }

    defstruct [:content, :finishReason, :safetyRatings]
  end

  defmodule SafetyRating do
    @derive Jason.Encoder
    @moduledoc """
    Safety rating for the response.
    """

    @type t :: %__MODULE__{
            category: String.t(),
            probability: String.t()
          }

    defstruct [:category, :probability]
  end

  defmodule ErrorResponse do
    @derive Jason.Encoder
    @moduledoc """
    Error response structure.
    """

    @type t :: %__MODULE__{
            error: %{
              code: integer(),
              message: String.t(),
              status: String.t()
            }
          }

    defstruct error: %{code: nil, message: nil, status: nil}
  end
end
