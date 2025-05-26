defmodule Core.Ai.Gemini.Behaviour do
  @moduledoc """
  Behaviour module defining the contract for Gemini API interactions.
  """

  alias Core.External.Gemini.Models
  alias Core.Ai.Gemini.Config

  @type error ::
          {:invalid_request, String.t()}
          | {:unsupported_model, atom()}
          | {:json_encode_error, term()}
          | {:http_error, term()}
          | {:invalid_response, String.t()}
          | {:api_error, String.t()}

  @callback ask(Models.AskAIRequest.t(), Config.t()) ::
              {:ok, String.t()} | {:error, error()}
  @callback ask(Models.AskAIRequest.t()) ::
              {:ok, String.t()} | {:error, error()}
end
