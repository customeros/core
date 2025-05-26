defmodule Core.Ai.Webpage.Classify.Behaviour do
  @moduledoc """
  Behaviour for webpage classification.
  """

  @callback classify_webpage_content(domain :: String.t(), content :: String.t()) ::
              {:ok, map()} | {:error, term()}
end
