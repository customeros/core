defmodule Core.Utils.StructUtils do
  @moduledoc """
  Utility functions for safely working with structs.
  """

  @doc """
  Safely creates a struct by filtering out unknown fields from the input map.

  This prevents crashes when external APIs return data with fields that don't
  exist in the struct definition.

  ## Examples

      iex> safe_struct(%{name: "John", age: 30, unknown_field: "value"}, User)
      %User{name: "John", age: 30}

      iex> safe_struct(%{name: "John"}, User)
      %User{name: "John"}
  """
  def safe_struct(map, struct_module) when is_map(map) do
    struct_fields = struct_module.__struct__() |> Map.keys()

    # Filter map to only include known struct fields
    filtered_map =
      map
      |> Map.take(struct_fields)
      |> Map.filter(fn {_key, value} -> value != :__struct__ end)

    struct(struct_module, filtered_map)
  end
end
