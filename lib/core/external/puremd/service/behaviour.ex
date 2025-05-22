defmodule Core.External.Puremd.Service.Behaviour do
  @moduledoc """
  Behaviour for PureMD service.
  """

  @callback fetch_page(url :: String.t()) ::
              {:ok, String.t()} | {:error, term()}
end
