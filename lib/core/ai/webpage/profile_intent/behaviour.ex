defmodule Core.Ai.Webpage.ProfileIntent.Behaviour do
  @moduledoc """
  Behaviour for Webpage Profile Intent service.
  """

  alias Core.Ai.Webpage.Intent

  @callback profile_webpage_intent(url :: String.t(), content :: String.t()) ::
              {:ok, %Core.Ai.Webpage.Intent{}} | {:error, term()}
end
