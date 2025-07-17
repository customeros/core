defmodule Core.Utils.DomainIO do
  @moduledoc """
  Domain I/O utilities with improved error handling for SSL/certificate issues
  """
  alias Core.Utils.TaskAwaiter
  alias Finch.Response
  require Logger

  @err_cannot_resolve_url {:error, :cannot_resolve_url}
  @err_empty_url {:error, "url is empty"}
  @err_invalid_url {:error, "invalid url"}
  @err_ssl_error {:error, "ssl certificate error"}
  @err_timeout {:error, "request timeout"}

  @resolve_timeout_ms 6000

  def test_redirect(url) when is_binary(url) and byte_size(url) > 0 do
    case Task.Supervisor.async_nolink(Core.TaskSupervisor, fn ->
           test_redirect_call(url)
         end)
         |> TaskAwaiter.await(@resolve_timeout_ms) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  def test_redirect(nil), do: @err_empty_url
  def test_redirect(""), do: @err_empty_url
  def test_redirect(_), do: @err_invalid_url

  defp test_redirect_call(url) do
    request =
      Finch.build(:get, url, [
        {"user-agent",
         "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36"}
      ])

    try do
      case Finch.request(request, Core.FinchRelaxedTLS,
                         receive_timeout: 5000) do
        {:ok, %Response{status: status, headers: headers}}
        when status >= 300 and status < 400 ->
          {:ok, {:redirect, headers}}

        {:ok, %Response{}} ->
          {:ok, {:no_redirect}}

        {:error,
         %Mint.TransportError{reason: {:tls_alert, {:certificate_unknown, _}}}} ->
          Logger.warning("Certificate unknown error for #{url}")
          @err_ssl_error

        {:error, %Mint.TransportError{reason: {:tls_alert, _}}} ->
          Logger.warning("TLS alert error for #{url}")
          @err_ssl_error

        {:error, reason} ->
          Logger.warning("HTTP request failed for #{url}: #{inspect(reason)}")
          @err_cannot_resolve_url
      end
    rescue
      error ->
        Logger.error("Unexpected error for #{url}: #{inspect(error)}",
          url: url
        )

        @err_cannot_resolve_url
    catch
      :exit,
      {{{:case_clause, {:error, {:asn1, reason}}}, _stacktrace}, _call_stack} ->
        Logger.warning(
          "ASN.1 certificate parsing error for #{url}: #{inspect(reason)}"
        )

        @err_ssl_error

      :exit, {{:tls_alert, _}, _} ->
        Logger.warning("TLS alert exit for #{url}")
        @err_ssl_error

      :exit, {:timeout, _} ->
        Logger.warning("Connection timeout for #{url}")
        @err_timeout

      :exit, {reason, _} ->
        Logger.warning("Connection exit for #{url}: #{inspect(reason)}")
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
      nil -> @err_timeout
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
          if valid_domain_for_tcp?(domain) do
            domain
            |> String.to_charlist()
            |> establish_connection(port)
          else
            Logger.debug(
              "Domain #{domain} contains invalid characters for TCP connection"
            )

            false
          end
        end)

      {:ok, result}
    rescue
      error ->
        Logger.debug(
          "Reachability test failed for #{domain}: #{inspect(error)}"
        )

        @err_cannot_resolve_url
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

  # Check if domain contains only ASCII characters valid for TCP connections
  defp valid_domain_for_tcp?(domain) when is_binary(domain) do
    # Check if all characters are ASCII (0-127) and valid for hostnames
    domain
    |> String.to_charlist()
    |> Enum.all?(fn char ->
      # Allow ASCII letters, digits, hyphens, and dots
      (char >= ?a and char <= ?z) or
        (char >= ?A and char <= ?Z) or
        (char >= ?0 and char <= ?9) or
        char == ?- or
        char == ?.
    end)
  end

  defp valid_domain_for_tcp?(_), do: false
end
