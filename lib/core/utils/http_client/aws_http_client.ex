defmodule Core.Utils.HttpClient.AwsHttpClient do
  @moduledoc """
  Custom HTTP client for ExAws using Finch.
  Implements the ExAws.Request.HttpClient behaviour.
  """

  @behaviour ExAws.Request.HttpClient

  require Logger

  @impl true
  def request(method, url, body, headers, http_opts) do
    case http_opts do
      [] -> :noop
      opts -> Logger.debug("ExAws HTTP options: #{inspect(opts)}")
    end

    with {:ok, resp} <-
           Finch.build(method, url, headers, body)
           |> Finch.request(Core.Finch) do
      {:ok, %{status_code: resp.status, body: resp.body, headers: resp.headers}}
    else
      {:error, reason} ->
        Logger.error("ExAws HTTP request failed: #{inspect(reason)}")
        {:error, %{reason: reason}}
    end
  end
end
