defmodule Core.Ai.Webpage.ProfileIntent.Behaviour do
  @moduledoc """
  Behaviour module defining the contract for webpage intent profiling.
  """

  alias Core.Ai.Webpage.Intent

  @callback profile_webpage_intent(String.t(), String.t()) :: {:ok, Intent.t()} | {:error, term()}
end
