defmodule Core.Researcher.IcpFitEvaluator.Validator do
  @moduledoc """
  Validates and parses ICP fit evaluation responses.
  This module handles:
  * Validation of ICP fit responses
  * Parsing of fit values into atoms
  * Validation of disqualification reasons for "not a fit" responses
  * JSON response validation
  * Error handling for invalid responses
  It ensures that ICP fit evaluations follow a strict format
  and can only return valid fit values (:strong, :moderate,
  or :not_a_fit) with appropriate disqualification reasons when applicable.
  """

  @valid_fits ["strong", "moderate", "not_a_fit", "unknown"]
  @fit_atoms %{
    "strong" => :strong,
    "moderate" => :moderate,
    "not_a_fit" => :not_a_fit,
    "unknown" => :unknown
  }

  @valid_disqualification_reasons [
    "company_too_small",
    "company_too_large",
    "startup_too_early",
    "wrong_industry",
    "regulated_industry_mismatch",
    "wrong_geography",
    "regulatory_restrictions",
    "wrong_business_model",
    "revenue_model_mismatch",
    "market_position_mismatch",
    "incompatible_tech_stack",
    "legacy_system_constraints",
    "no_use_case",
    "competitor",
    "unable_to_determine_fit"
  ]

  @reason_atoms %{
    "company_too_small" => :company_too_small,
    "company_too_large" => :company_too_large,
    "startup_too_early" => :startup_too_early,
    "wrong_industry" => :wrong_industry,
    "regulated_industry_mismatch" => :regulated_industry_mismatch,
    "wrong_geography" => :wrong_geography,
    "regulatory_restrictions" => :regulatory_restrictions,
    "wrong_business_model" => :wrong_business_model,
    "revenue_model_mismatch" => :revenue_model_mismatch,
    "market_position_mismatch" => :market_position_mismatch,
    "incompatible_tech_stack" => :incompatible_tech_stack,
    "legacy_system_constraints" => :legacy_system_constraints,
    "no_use_case" => :no_use_case,
    "competitor" => :competitor,
    "unable_to_determine_fit" => :unable_to_determine_fit
  }

  def validate_and_parse(response) when is_binary(response) do
    with {:ok, parsed} <- Jason.decode(response),
         {:ok, result} <- extract_icp_evaluation(parsed) do
      {:ok, result}
    else
      {:error, %Jason.DecodeError{}} ->
        {:error, "Invalid JSON format in AI response"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate_and_parse(_), do: {:error, "Response must be a string"}

  # Handle "not a fit" responses with reasons
  defp extract_icp_evaluation(%{"icp_fit" => "not_a_fit", "reasons" => reasons})
       when is_list(reasons) do
    with {:ok, validated_reasons} <- validate_reasons(reasons) do
      {:ok,
       %{icp_fit: :not_a_fit, icp_disqualification_reason: validated_reasons}}
    end
  end

  # Handle "not a fit" responses missing reasons
  defp extract_icp_evaluation(%{"icp_fit" => "not_a_fit"}) do
    {:error, "Missing required 'reasons' field for 'not_a_fit' response"}
  end

  # Handle "strong" and "moderate" responses (no reasons expected)
  defp extract_icp_evaluation(%{"icp_fit" => fit})
       when fit in ["strong", "moderate"] do
    {:ok, %{icp_fit: Map.get(@fit_atoms, fit), icp_disqualification_reason: []}}
  end

  # Handle invalid icp_fit values
  defp extract_icp_evaluation(%{"icp_fit" => fit}) when is_binary(fit) do
    trimmed_fit = String.trim(fit)

    {:error,
     "Invalid icp_fit value: '#{trimmed_fit}'. Must be one of: #{Enum.join(@valid_fits, ", ")}"}
  end

  # Handle case where icp_fit is missing
  defp extract_icp_evaluation(%{} = parsed)
       when not is_map_key(parsed, "icp_fit") do
    {:error, "Missing required field: icp_fit"}
  end

  # Handle case where icp_fit is not a string
  defp extract_icp_evaluation(%{"icp_fit" => fit}) when not is_binary(fit) do
    {:error, "icp_fit must be a string, got: #{inspect(fit)}"}
  end

  # Handle completely unexpected structure
  defp extract_icp_evaluation(parsed) do
    {:error, "Unexpected JSON structure: #{inspect(parsed)}"}
  end

  defp validate_reasons(reasons) when is_list(reasons) do
    if Enum.empty?(reasons) do
      {:error, "Reasons list cannot be empty for 'not_a_fit' response"}
    else
      case validate_reason_list(reasons, []) do
        {:ok, validated} -> {:ok, Enum.reverse(validated)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp validate_reasons(_) do
    {:error, "Reasons must be a list"}
  end

  defp validate_reason_list([], acc), do: {:ok, acc}

  defp validate_reason_list([reason | rest], acc) when is_binary(reason) do
    trimmed_reason = String.trim(reason)

    if trimmed_reason in @valid_disqualification_reasons do
      atom_reason = Map.get(@reason_atoms, trimmed_reason)
      validate_reason_list(rest, [atom_reason | acc])
    else
      {:error,
       "Invalid disqualification reason: '#{trimmed_reason}'. Must be one of: #{Enum.join(@valid_disqualification_reasons, ", ")}"}
    end
  end

  defp validate_reason_list([reason | _], _) do
    {:error,
     "Disqualification reason must be a string, got: #{inspect(reason)}"}
  end
end
