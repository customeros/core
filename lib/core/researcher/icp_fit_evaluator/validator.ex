defmodule Core.Researcher.IcpFitEvaluator.Validator do
  @moduledoc """
  Validates and parses ICP fit evaluation responses.

  This module handles:
  * Validation of ICP fit responses
  * Parsing of fit values into atoms
  * JSON response validation
  * Error handling for invalid responses

  It ensures that ICP fit evaluations follow a strict format
  and can only return valid fit values (:strong, :moderate,
  or :not_a_fit). The module provides clear error messages
  for any validation failures.
  """

  @valid_fits ["strong", "moderate", "not a fit"]
  @fit_atoms %{
    "strong" => :strong,
    "moderate" => :moderate,
    "not a fit" => :not_a_fit
  }

  def validate_and_parse(response) when is_binary(response) do
    with {:ok, parsed} <- Jason.decode(response),
         {:ok, fit} <- extract_icp_fit(parsed) do
      {:ok, fit}
    else
      {:error, %Jason.DecodeError{}} ->
        {:error, "Invalid JSON format in AI response"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate_and_parse(_), do: {:error, "Response must be a string"}

  # Handle the expected simple schema from your system prompt
  defp extract_icp_fit(%{"icp_fit" => fit}) when is_binary(fit) do
    trimmed_fit = String.trim(fit)

    if trimmed_fit in @valid_fits do
      {:ok, Map.get(@fit_atoms, trimmed_fit)}
    else
      {:error,
       "Invalid icp_fit value: '#{trimmed_fit}'. Must be one of: #{Enum.join(@valid_fits, ", ")}"}
    end
  end

  # Handle case where icp_fit is missing
  defp extract_icp_fit(%{} = parsed) when not is_map_key(parsed, "icp_fit") do
    {:error, "Missing required field: icp_fit"}
  end

  # Handle case where icp_fit is not a string
  defp extract_icp_fit(%{"icp_fit" => fit}) when not is_binary(fit) do
    {:error, "icp_fit must be a string, got: #{inspect(fit)}"}
  end

  # Handle completely unexpected structure
  defp extract_icp_fit(parsed) do
    {:error, "Unexpected JSON structure: #{inspect(parsed)}"}
  end
end
