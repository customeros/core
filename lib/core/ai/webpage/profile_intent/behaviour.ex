defmodule Core.Ai.Webpage.ProfileIntent.Behaviour do
  @moduledoc """
  Behaviour for webpage intent profiling.
  """

  @callback profile_webpage_intent(domain :: String.t(), content :: String.t()) ::
              {:ok, map()} | {:error, term()}
end
