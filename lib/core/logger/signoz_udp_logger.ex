defmodule Core.Logger.SignozUdpLogger do
  @moduledoc """
  A Logger backend that sends log messages to SigNoz via UDP.
  
  This backend uses UDP sockets to send logs to SigNoz's UDP receiver,
  avoiding HTTP connection pool issues and providing better reliability.
  
  ## Configuration
  
  - `:host` - SigNoz UDP receiver host (default: "10.0.16.2")
  - `:port` - SigNoz UDP receiver port (default: 54525)
  - `:env` - Environment name (default: "production")
  - `:service_name` - Service name for identification (default: "core")
  - `:batch_size` - Number of logs to batch before sending (default: 50)
  - `:batch_timeout` - Maximum time to wait before flushing batch in ms (default: 2000)
  
  ## Usage
  
      config :logger,
        backends: [:console, {Core.Logger.SignozUdpLogger, [
          host: "10.0.16.2",
          port: 54525,
          env: "production",
          service_name: "my-app",
          batch_size: 50,
          batch_timeout: 2000
        ]}]
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
    log_entry = build_log_entry(level, msg, ts, md, state)
    new_state = add_to_batch(log_entry, state)
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

  def terminate(_reason, state) do
    # Flush any remaining logs before terminating
    flush_batch(state)
    if state.socket do
      :gen_udp.close(state.socket)
    end
    :ok
  end

  defp configure(opts) do
    host = Keyword.get(opts, :host, "10.0.16.2")
    port = Keyword.get(opts, :port, 54525)
    env = Keyword.get(opts, :env, "production")
    service_name = Keyword.get(opts, :service_name, "core")
    batch_size = Keyword.get(opts, :batch_size, 50)
    batch_timeout = Keyword.get(opts, :batch_timeout, 2000)
    
    # Open UDP socket
    {:ok, socket} = :gen_udp.open(0, [:binary, {:active, false}])
    
    %{
      host: parse_host(host),
      port: port,
      env: env,
      service_name: service_name,
      batch_size: batch_size,
      batch_timeout: batch_timeout,
      socket: socket,
      batch: []
    }
  end

  defp parse_host(host) when is_binary(host) do
    case :inet.getaddr(String.to_charlist(host), :inet) do
      {:ok, ip} -> ip
      {:error, _} -> {10, 0, 16, 2}  # fallback
    end
  end

  defp parse_host(host) when is_tuple(host), do: host

  defp schedule_batch_send do
    Process.send_after(self(), :batch_send, 2000)
  end

  defp build_log_entry(level, msg, timestamp, metadata, state) do
    {severity_text, _severity_number} = map_log_level(level)
    
    # Convert timestamp to ISO8601 format
    timestamp_str = case timestamp do
      {date, {hour, min, sec, micro}} ->
        datetime = NaiveDateTime.from_erl!({date, {hour, min, sec}}, {micro, 6})
        DateTime.from_naive!(datetime, "Etc/UTC")
        |> DateTime.to_iso8601()
      _ ->
        DateTime.utc_now() |> DateTime.to_iso8601()
    end
    
    # Build structured log message similar to standard log formats
    # Format: [timestamp] [level] [service] message [metadata]
    metadata_str = format_metadata_string(metadata)
    
    log_message = "[#{timestamp_str}] [#{severity_text}] [#{state.service_name}] #{to_string(msg)}"
    
    # Add metadata if present
    if metadata_str != "" do
      log_message <> " " <> metadata_str
    else
      log_message
    end
  end

  defp add_to_batch(log_entry, state) do
    new_batch = [log_entry | state.batch]
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
    if state.socket do
      # Send each log entry as a separate UDP packet
      Enum.each(state.batch, fn log_entry ->
        :gen_udp.send(state.socket, state.host, state.port, log_entry)
      end)
    end
    
    %{state | batch: []}
  end

  defp map_log_level(:debug), do: {"DEBUG", 5}
  defp map_log_level(:info), do: {"INFO", 9}
  defp map_log_level(:warn), do: {"WARN", 13}
  defp map_log_level(:error), do: {"ERROR", 17}
  defp map_log_level(_), do: {"INFO", 9}

  defp format_metadata_string(metadata) do
    case metadata do
      [] -> ""
      _ ->
        metadata_pairs = 
          metadata
          |> Enum.map(fn {key, value} ->
            "#{key}=#{safe_to_string(value)}"
          end)
          |> Enum.join(" ")
        
        "[#{metadata_pairs}]"
    end
  end

  defp safe_to_string(value) when is_pid(value), do: inspect(value)
  defp safe_to_string(value) when is_reference(value), do: inspect(value)
  defp safe_to_string(value) when is_port(value), do: inspect(value)
  defp safe_to_string(value) when is_function(value), do: inspect(value)
  defp safe_to_string(value) when is_map(value), do: inspect(value)
  defp safe_to_string(value) when is_tuple(value), do: inspect(value)

  defp safe_to_string(value) when is_list(value) do
    case Enum.all?(value, &is_integer/1) and List.ascii_printable?(value) do
      true -> to_string(value)
      false -> inspect(value)
    end
  end

  defp safe_to_string(value) do
    try do
      to_string(value)
    rescue
      Protocol.UndefinedError -> inspect(value)
    end
  end
end