defmodule Core.Ai.Webpage.Classify.Behaviour do
  @moduledoc """
  Behaviour for Webpage Classify service.
  """

  @callback classify_webpage_content(url :: String.t(), content :: String.t()) ::
              {:ok, %Core.Ai.Webpage.Classification{}} | {:error, term()}
end
