defmodule Core.Ai.Webpage.Classify.Behaviour do
  @moduledoc """
  Behaviour module defining the contract for webpage classification.
  """

  alias Core.Ai.Webpage.Classification

  @callback classify_webpage_content(String.t(), String.t()) :: {:ok, Classification.t()} | {:error, term()}
end
