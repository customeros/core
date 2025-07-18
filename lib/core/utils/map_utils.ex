defmodule Core.Utils.MapUtils do
  @moduledoc """
  Utility functions for maps.
  """

  def to_camel_case_map(map) when is_map(map) do
    map
    |> Map.delete(:__meta__)
    |> Enum.map(fn {key, value} ->
      new_key =
        key
        |> to_string()
        |> Macro.camelize()
        |> String.replace(~r/^./, &String.downcase/1)

      {new_key, transform_value(value)}
    end)
    |> Enum.into(%{})
  end

  def to_snake_case_map(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} ->
      new_key =
        key
        |> to_string()
        |> Macro.underscore()
        |> String.to_atom()

      {new_key, transform_value_snake(value)}
    end)
    |> Enum.into(%{})
  end

  defp transform_value(%DateTime{} = datetime), do: datetime
  defp transform_value(value) when is_map(value), do: to_camel_case_map(value)

  defp transform_value(value) when is_list(value),
    do: Enum.map(value, &transform_value/1)

  defp transform_value(value), do: value

  defp transform_value_snake(%{} = value), do: to_snake_case_map(value)

  defp transform_value_snake([head | tail]),
    do: [transform_value_snake(head) | transform_value_snake(tail)]

  defp transform_value_snake([]), do: []
  defp transform_value_snake(value), do: value
end
