defmodule Core.Utils.DomainIO do
  @moduledoc """
  """
  alias Finch.Response
  @err_cannot_resolve_url {:error, "url does not resolve"}
  @err_empty_url {:error, "url is empty"}
  @err_invalid_url {:error, "invalid url"}

  def test_redirect(url)
      when is_binary(url) and byte_size(url) > 0 do
    case Task.Supervisor.async_nolink(Core.TaskSupervisor, fn ->
           test_redirect_call(url)
         end)
         |> Task.yield(6000) do
      {:ok, result} -> result
      nil -> @err_cannot_resolve_url
    end
  end

  def test_redirect(nil), do: @err_empty_url
  def test_redirect(""), do: @err_empty_url
  def test_redirect(_), do: @err_invalid_url

  defp test_redirect_call(url) do
    request =
      Finch.build(:get, url, [
        {"user-agent",
         "mozilla/5.0 (windows nt 10.0; win64; x64) applewebkit/537.36 (khtml, like gecko) chrome/91.0.4472.124 safari/537.36"}
      ])

    try do
      case Finch.request(request, Core.Finch, receive_timeout: 5000) do
        {:ok, %Response{status: status, headers: headers}}
        when status >= 300 and status < 400 ->
          {:ok, {:redirect, headers}}

        {:ok, %Response{}} ->
          {:ok, {:no_redirect}}

        {:error, _} ->
          @err_cannot_resolve_url
      end
    rescue
      _ ->
        @err_cannot_resolve_url
    end
  end

  def test_reachability(domain)
      when is_binary(domain) and byte_size(domain) > 0 do
    case Task.Supervisor.async_nolink(
           Core.TaskSupervisor,
           fn ->
             test_reachability_call(domain)
           end
         )
         |> Task.yield(6000) do
      {:ok, result} -> result
      nil -> @err_cannot_resolve_url
    end
  end

  def test_reachability(nil), do: @err_empty_url
  def test_reachability(""), do: @err_empty_url
  def test_reachability(_), do: @err_invalid_url

  defp test_reachability_call(domain) do
    try do
      result =
        [80, 443]
        |> Enum.any?(fn port ->
          domain
          |> String.to_charlist()
          |> establish_connection(port)
        end)

      {:ok, result}
    rescue
      _ -> @err_cannot_resolve_url
    end
  end

  defp establish_connection(domain_charlist, port) do
    case :gen_tcp.connect(domain_charlist, port, [], 1000) do
      {:ok, conn} ->
        :gen_tcp.close(conn)
        true

      {:error, _} ->
        false
    end
  end
end
