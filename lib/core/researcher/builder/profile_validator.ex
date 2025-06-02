defmodule Core.Researcher.Builder.ProfileValidator do
  @moduledoc """
  Validates and parses AI responses into Profile structs.

  This module manages:
  * JSON response validation
  * Profile data parsing
  * Required field validation
  * Error handling and reporting
  * Profile struct construction

  It ensures that AI-generated profile responses are properly
  formatted and contain all required fields for a valid Profile
  struct. The module handles various error cases including
  invalid JSON, missing fields, and malformed data, providing
  clear error messages for debugging.
  """

  alias Core.Researcher.Builder.Profile

  @doc """
  Validates and parses the AI response into a Profile struct.

  Expected JSON format:
  {
    "profile": "Description of ideal customer profile",
    "qualifying_attributes": ["Attribute 1", "Attribute 2", ...]
  }
  """
  def validate_and_parse(response) when is_binary(response) do
    with {:ok, parsed} <- Jason.decode(response),
         {:ok, profile} <- extract_profile_data(parsed) do
      {:ok, profile}
    else
      {:error, %Jason.DecodeError{}} ->
        {:error, "Invalid JSON format in AI response"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate_and_parse(_), do: {:error, "Response must be a string"}

  defp extract_profile_data(%{
         "profile" => profile,
         "qualifying_attributes" => attributes
       })
       when is_binary(profile) and is_list(attributes) do
    # Validate that all attributes are strings
    case validate_attributes(attributes) do
      :ok ->
        {:ok,
         %Profile{
           icp: String.trim(profile),
           qualifying_attributes: Enum.map(attributes, &String.trim/1)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_profile_data(%{"profile" => _}) do
    {:error, "Missing or invalid 'qualifying_attributes' field"}
  end

  defp extract_profile_data(%{"qualifying_attributes" => _}) do
    {:error, "Missing or invalid 'profile' field"}
  end

  defp extract_profile_data(_) do
    {:error, "Missing required fields: 'profile' and 'qualifying_attributes'"}
  end

  defp validate_attributes(attributes) do
    case Enum.all?(attributes, &is_binary/1) do
      true -> :ok
      false -> {:error, "All qualifying attributes must be strings"}
    end
  end
end
