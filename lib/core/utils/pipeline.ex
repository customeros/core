defmodule Core.Utils.Pipeline do
  @moduledoc """
  Custom error-aware pipeline operator.
  """
  def ok({:ok, value}, func), do: func.(value)
  def ok({:ok, value1, value2}, func), do: func.(value1, value2)
  def ok({:error, _} = error, _func), do: error
  def ok(value, func), do: func.(value)
end
