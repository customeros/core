defmodule Core.WebTracker.StageIdentifier.SessionContext do
  @moduledoc """
  Struct representing the context for Lead Stage identification from a websession.
  """

  defstruct [:url, :summary, :intent]
end
