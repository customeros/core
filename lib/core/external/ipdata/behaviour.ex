defmodule Core.External.IPData.Behaviour do
  @moduledoc """
  Behaviour for IPData service.
  """

  @callback verify_ip(String.t()) :: {:ok, map()} | {:error, term()}
end
