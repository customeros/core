defmodule Core.Logger.SignozLogger do
  @moduledoc """
  A Logger backend that sends log messages to SignOz observability platform.

  This module implements the `:gen_event` behaviour to integrate with Elixir's Logger
  system and forwards log messages to SignOz via HTTP POST requests.

  ## Configuration

  The logger can be configured with the following options:

  - `:env` - Environment name (default: "production")
  - `:endpoint` - SignOz endpoint URL (default: "http://10.0.16.2:4318/v1/logs")
  - `:service_name` - Service name for identification (default: "core")

  ## Usage

  Add this backend to your Logger configuration:

      config :logger,
        backends: [:console, {Logger.Backends.SignozLogger, [
          env: "production",
          endpoint: "http://your-signoz-instance:4318/v1/logs",
          service_name: "my-app"
        ]}]

  ## Log Format

  Logs are sent to SignOz in OpenTelemetry format with:
  - Resource attributes (service name, version, environment)
  - Log level mapping to OpenTelemetry severity levels
  - Metadata converted to attributes
  - Timestamp in nanoseconds
  """
  @behaviour :gen_event

  # Handle when called with {module, opts} tuple
  def init({__MODULE__, opts}) do
    state = configure(opts)
    schedule_batch_send()
    {:ok, state}
  end

  # Handle when called with just the module name (no opts)
  def init(__MODULE__) do
    state = configure([])
    schedule_batch_send()
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, state) do
    log_record = build_log_record(level, msg, ts, md)
    new_state = add_to_batch(log_record, state)
    {:ok, new_state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  def handle_call({:configure, opts}, _state) do
    {:ok, :ok, configure(opts)}
  end

  def handle_info(:batch_send, state) do
    new_state = flush_batch(state)
    schedule_batch_send()
    {:ok, new_state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp configure(opts) do
    env = Keyword.get(opts, :env, "production")
    endpoint = Keyword.get(opts, :endpoint, "http://10.0.16.2:4318/v1/logs")
    service_name = Keyword.get(opts, :service_name, "core")
    batch_size = Keyword.get(opts, :batch_size, 100)
    batch_timeout = Keyword.get(opts, :batch_timeout, 5_000)

    %{
      env: env,
      endpoint: endpoint,
      service_name: service_name,
      batch_size: batch_size,
      batch_timeout: batch_timeout,
      batch: []
    }
  end

  defp schedule_batch_send do
    Process.send_after(self(), :batch_send, 5_000)
  end

  defp build_log_record(level, msg, _timestamp, metadata) do
    {severity_text, severity_number} = map_log_level(level)

    %{
      "timeUnixNano" => "#{System.system_time(:nanosecond)}",
      "severityNumber" => severity_number,
      "severityText" => severity_text,
      "body" => %{"stringValue" => to_string(msg)},
      "attributes" => build_attributes(metadata)
    }
  end

  defp add_to_batch(log_record, state) do
    new_batch = [log_record | state.batch]
    new_state = %{state | batch: new_batch}

    # Check if we should flush due to batch size
    if length(new_batch) >= state.batch_size do
      flush_batch(new_state)
    else
      new_state
    end
  end

  defp flush_batch(%{batch: []} = state), do: state

  defp flush_batch(state) do
    payload = %{
      "resourceLogs" => [
        %{
          "resource" => %{
            "attributes" => [
              %{
                "key" => "service.name",
                "value" => %{"stringValue" => state.service_name}
              },
              %{
                "key" => "service.version",
                "value" => %{"stringValue" => "0.1.86"}
              },
              %{
                "key" => "environment",
                "value" => %{"stringValue" => state.env}
              }
            ]
          },
          "scopeLogs" => [
            %{
              "scope" => %{"name" => "elixir-logger"},
              "logRecords" => Enum.reverse(state.batch)
            }
          ]
        }
      ]
    }

    Task.start(fn ->
      try do
        Finch.build(
          :post,
          state.endpoint,
          [
            {"Content-Type", "application/json"}
          ],
          Jason.encode!(payload)
        )
        |> Finch.request(Core.Finch,
          receive_timeout: 10_000,
          request_timeout: 15_000
        )
        |> case do
          {:ok, %{status: status}} when status in 200..299 ->
            :ok

          {:ok, %{status: status}} ->
            IO.puts("SigNoz batch send failed with status: #{status}")

          {:error, reason} ->
            IO.puts("SigNoz batch send failed: #{inspect(reason)}")
        end
      rescue
        error ->
          IO.puts("SigNoz batch send crashed: #{inspect(error)}")
      end
    end)

    %{state | batch: []}
  end

  defp map_log_level(:debug), do: {"DEBUG", 5}
  defp map_log_level(:info), do: {"INFO", 9}
  defp map_log_level(:warn), do: {"WARN", 13}
  defp map_log_level(:error), do: {"ERROR", 17}
  defp map_log_level(_), do: {"INFO", 9}

  defp build_attributes(metadata) do
    metadata
    |> Enum.map(fn {key, value} ->
      %{
        "key" => to_string(key),
        "value" => %{"stringValue" => safe_to_string(value)}
      }
    end)
  end

  defp safe_to_string(value) when is_pid(value), do: inspect(value)
  defp safe_to_string(value) when is_reference(value), do: inspect(value)
  defp safe_to_string(value) when is_port(value), do: inspect(value)
  defp safe_to_string(value) when is_function(value), do: inspect(value)
  defp safe_to_string(value) when is_map(value), do: inspect(value)
  defp safe_to_string(value) when is_tuple(value), do: inspect(value)

  defp safe_to_string(value) when is_list(value) do
    # Handle lists that might contain complex data
    case Enum.all?(value, &is_integer/1) and List.ascii_printable?(value) do
      # It's a charlist/string
      true -> to_string(value)
      # It's a regular list with complex data
      false -> inspect(value)
    end
  end

  defp safe_to_string(value) do
    # Fallback: try to_string first, if it fails use inspect
    try do
      to_string(value)
    rescue
      Protocol.UndefinedError -> inspect(value)
    end
  end
end
