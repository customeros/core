defmodule Core.External.HttpClient do
  @moduledoc """
  HTTP client implementation using Finch.
  """

  @behaviour Core.External.HttpClient.Behaviour

  alias Core.External.HttpClient.Behaviour

  @impl Behaviour
  def post(url, body, headers, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)

    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, Core.Finch, receive_timeout: timeout) do
      {:ok, %{status: status, body: body}} ->
        {:ok, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
