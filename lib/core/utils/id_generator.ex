defmodule Core.Utils.IdGenerator do
  @moduledoc """
  Helper module for generating unique IDs with prefixes.
  """

  @doc """
  Generates a unique ID with the given prefix.
  The ID will be in the format: prefix_<21 random lowercase alphanumeric characters>
  """
  @spec generate_id(String.t()) :: String.t()
  def generate_id(prefix) do
    random_string = for _ <- 1..21, into: "", do: <<Enum.random('abcdefghijklmnopqrstuvwxyz0123456789')>>
    "#{prefix}_#{random_string}"
  end
end
