defmodule Core.External.Jina.Behaviour do
  @moduledoc """
  Behaviour module defining the contract for Jina API interactions.
  """

  @callback fetch_page(String.t()) :: {:ok, String.t()} | {:error, term()}
end
