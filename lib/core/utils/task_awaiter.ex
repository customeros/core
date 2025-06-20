defmodule Core.Utils.TaskAwaiter do
  @moduledoc """
  A utility module for awaiting Task results with timeout handling.

  This module provides a simplified interface for waiting on Task results
  with proper timeout and error handling. It wraps `Task.yield/2` to provide
  a more convenient API for task result processing.

  ## Functions

  - `await/2` - Awaits a task result with a specified timeout

  ## Examples

      task = Task.async(fn -> some_expensive_operation() end)
      case TaskAwaiter.await(task, 5000) do
        {:ok, result} -> # Task completed successfully
        {:error, :timeout} -> # Task timed out
        {:error, reason} -> # Task failed with error
      end
  """
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
