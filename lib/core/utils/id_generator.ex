defmodule Core.Utils.IdGenerator do
  @moduledoc """
  Helper module for generating unique IDs with prefixes.
  """

  @doc """
  Generates a unique ID with the given prefix and 21 random characters.
  The ID will be in the format: prefix_<21 random lowercase alphanumeric characters>
  """
  @spec generate_id_21(String.t()) :: String.t()
  def generate_id_21(prefix) do
    "#{prefix}_#{generate_random_string(21)}"
  end

  @doc """
  Generates a unique ID with the given prefix and 16 random characters.
  The ID will be in the format: prefix_<16 random lowercase alphanumeric characters>
  """
  @spec generate_id_16(String.t()) :: String.t()
  def generate_id_16(prefix) do
    "#{prefix}_#{generate_random_string(16)}"
  end

  defp generate_random_string(length) do
    for _ <- 1..length, into: "", do: <<Enum.random('abcdefghijklmnopqrstuvwxyz0123456789')>>
  end
end
