defmodule Core.Logger.SignozLogger do
  @behaviour :gen_event

  def init({__MODULE__, opts}) do
    {:ok, configure(opts)}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, state) do
    send_to_signoz(level, msg, ts, md, state)
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  def handle_call({:configure, opts}, _state) do
    {:ok, :ok, configure(opts)}
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
    %{env: env, endpoint: endpoint, service_name: service_name}
  end

  defp send_to_signoz(level, msg, _timestamp, metadata, state) do
    {severity_text, severity_number} = map_log_level(level)

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
              "logRecords" => [
                %{
                  "timeUnixNano" => "#{System.system_time(:nanosecond)}",
                  "severityNumber" => severity_number,
                  "severityText" => severity_text,
                  "body" => %{"stringValue" => to_string(msg)},
                  "attributes" => build_attributes(metadata)
                }
              ]
            }
          ]
        }
      ]
    }

    Task.start(fn ->
      Finch.build(
        :post,
        state.endpoint,
        [
          {"Content-Type", "application/json"}
        ],
        Jason.encode!(payload)
      )
      |> Finch.request(Core.Finch)
    end)
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
        "value" => %{"stringValue" => to_string(value)}
      }
    end)
  end
end
