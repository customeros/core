defmodule Core.Ai.Webpage.ProfileIntent.Behaviour do
  @moduledoc """
  Behaviour for Webpage Profile Intent service.
  """

  @callback profile_webpage_intent(url :: String.t(), content :: String.t()) ::
              {:ok, %Core.Ai.Webpage.Intent{}} | {:error, term()}
end
