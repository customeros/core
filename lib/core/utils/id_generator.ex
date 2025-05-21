defmodule Core.Utils.IdGenerator do
  @moduledoc """
  Helper module for generating unique IDs with prefixes.
  """

  @alphabet "abcdefghijklmnopqrstuvwxyz1234567890"

  @doc """
  Generates a unique ID with the given prefix and 21 random characters.
  The ID will be in the format: prefix_<21 random lowercase alphanumeric characters>
  """
  @spec generate_id_21(String.t()) :: String.t()
  def generate_id_21(prefix) when is_binary(prefix) and prefix != "" do
    "#{prefix}_#{Nanoid.generate(21, @alphabet)}"
  end

  @doc """
  Generates a unique ID with the given prefix and 16 random characters.
  The ID will be in the format: prefix_<16 random lowercase alphanumeric characters>
  """
  @spec generate_id_16(String.t()) :: String.t()
  def generate_id_16(prefix) when is_binary(prefix) and prefix != "" do
    "#{prefix}_#{Nanoid.generate(16, @alphabet)}"
  end

  @spec generate_id(Integer.t()) :: String.t()
  def generate_id(size \\ 21) when is_integer(size) and size != 0 do
    Nanoid.generate(size, @alphabet)
  end
end
