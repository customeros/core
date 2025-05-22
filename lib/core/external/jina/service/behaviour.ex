defmodule Core.External.Jina.Service.Behaviour do
  @moduledoc """
  Behaviour for Jina service.
  """

  @callback fetch_page(url :: String.t()) ::
              {:ok, String.t()} | {:error, term()}
end
