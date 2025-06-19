defmodule Core.Logger.ApiLogger do
  @moduledoc """
  Handles logging of external API calls made with Finch.
  Includes OpenTelemetry tracing for all requests.
  """

  require Logger
  require OpenTelemetry.Tracer

  alias Core.Repo
  alias Core.Logger.ApiLog
  alias Core.Utils.Tracing
  alias Core.Utils.IdGenerator

  @type vendor :: String.t()

  # List of parameter names that should be redacted
  @sensitive_params [
    "api-key",
    "api_key",
    "apikey",
    "key",
    "token",
    "access_token",
    "secret"
  ]

  @doc """
  Makes a Finch request and logs its details.
  Automatically creates spans for tracing.
  """
  @spec request(Finch.Request.t(), vendor()) ::
          {:ok, Finch.Response.t()} | {:error, term()}
  def request(request, vendor)

  def request(%Finch.Request{} = request, vendor)
      when is_binary(vendor) and byte_size(vendor) > 0 do
    start_time = System.monotonic_time()

    OpenTelemetry.Tracer.with_span "http_client.request" do
      OpenTelemetry.Tracer.set_attributes([
        {"http.method", to_string(request.method)},
        {"http.url", construct_url(request)},
        {"http.vendor", vendor},
        {"http.target", request.path}
      ])

      try do
        case Finch.request(request, Core.Finch) do
          {:ok, response} = result ->
            OpenTelemetry.Tracer.set_attributes([
              {"result.http_status_code", response.status},
              {"result.success", response.status in 200..299}
            ])

            if response.status in 200..299 do
              Tracing.ok()
            end

            log_success(vendor, request, response, start_time)
            result

          {:error, reason} = error ->
            OpenTelemetry.Tracer.set_attributes([
              {"result.success", false},
              {"error.type", "request_failed"}
            ])

            Tracing.error(reason)
            log_error(vendor, request, reason, start_time)
            error
        end
      rescue
        e ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.success", false},
            {"error.type", "exception"},
            {"error.message", Exception.message(e)}
          ])

          Tracing.error(e)
          Logger.error("Request failed with exception: #{inspect(e)}")
          log_error(vendor, request, e, start_time)
          {:error, :request_failed}
      end
    end
  end

  def request(%Finch.Request{}, _vendor), do: {:error, :invalid_vendor}
  def request(_request, _vendor), do: {:error, :invalid_request}

  # Private functions

  defp construct_url(%Finch.Request{
         scheme: scheme,
         host: host,
         port: port,
         path: path,
         query: query
       }) do
    base_url = "#{scheme}://#{host}#{port_to_string(port)}#{path}"

    if query,
      do: "#{base_url}?#{redact_sensitive_params(query)}",
      else: base_url
  end

  defp port_to_string(443), do: ""
  defp port_to_string(80), do: ""
  defp port_to_string(port) when is_integer(port), do: ":#{port}"
  defp port_to_string(_), do: ""

  defp redact_sensitive_params(nil), do: nil

  defp redact_sensitive_params(query) do
    query
    |> String.split("&")
    |> Enum.map_join("&", &redact_param/1)
  end

  defp redact_param(param) do
    [key | _] = String.split(param, "=", parts: 2)

    if Enum.any?(@sensitive_params, &String.contains?(String.downcase(key), &1)) do
      "#{key}=[REDACTED]"
    else
      param
    end
  end

  defp log_success(vendor, request, response, start_time) do
    duration = System.monotonic_time() - start_time
    duration_ms = System.convert_time_unit(duration, :native, :millisecond)

    attrs = %{
      id: IdGenerator.generate_id_21(ApiLog.id_prefix()),
      vendor: vendor,
      method: request.method,
      url: construct_url(request),
      request_body: request.body,
      duration: duration_ms,
      status_code: response.status,
      response_body: response.body
    }

    Task.start(fn ->
      %ApiLog{}
      |> ApiLog.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, _log} ->
          :ok

        {:error, error} ->
          Logger.error("Failed to log API call: #{inspect(error)}")
      end
    end)
  end

  defp log_error(vendor, request, reason, start_time) do
    duration = System.monotonic_time() - start_time
    duration_ms = System.convert_time_unit(duration, :native, :millisecond)

    attrs = %{
      id: IdGenerator.generate_id_21(ApiLog.id_prefix()),
      vendor: vendor,
      method: request.method,
      url: construct_url(request),
      request_body: request.body,
      duration: duration_ms,
      error_message: "#{inspect(reason)}"
    }

    Task.start(fn ->
      %ApiLog{}
      |> ApiLog.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, _log} ->
          :ok

        {:error, error} ->
          Logger.error("Failed to log API call: #{inspect(error)}")
      end
    end)
  end
end
