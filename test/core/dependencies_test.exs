defmodule Core.DependenciesTest do
  use ExUnit.Case

  test "project does not use HTTPoison" do
    # Get all loaded modules
    modules = :code.all_loaded()

    # Check if HTTPoison is loaded
    has_httpoison = Enum.any?(modules, fn {module, _} ->
      module |> to_string() |> String.contains?("HTTPoison")
    end)

    refute has_httpoison, "HTTPoison should not be used in this project"
  end
end
