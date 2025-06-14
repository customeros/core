defmodule Core.Utils.TaskAwaiter do
  @err_timeout {:error, :timeout}

  def await(task, timeout) do
    case Task.yield(task, timeout) do
      {:ok, {:ok, response}} -> {:ok, response}
      {:ok, {:error, reason}} -> {:error, reason}
      {:exit, reason} -> {:error, reason}
      nil -> @err_timeout
    end
  end
end
