defmodule Core.External.Puremd.Behaviour do
  @moduledoc """
  Behaviour module defining the contract for PureMD API interactions.
  """

  @callback fetch_page(String.t()) :: {:ok, String.t()} | {:error, term()}
end
