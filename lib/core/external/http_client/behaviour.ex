defmodule Core.External.HttpClient.Behaviour do
  @moduledoc """
  Behaviour for HTTP client operations.
  """

  @type response :: %{status: integer(), body: String.t()}

  @callback post(url :: String.t(), body :: String.t(), headers :: [{String.t(), String.t()}], opts :: keyword()) ::
              {:ok, response()} | {:error, term()}
end
