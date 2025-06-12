defmodule Core.Utils.DomainValidator do
  @moduledoc """
  Functions for domain parsing and validation using IDNA standards.

  This module provides comprehensive domain validation, normalization, and parsing
  utilities. It handles internationalized domain names (IDN) and multi-level TLDs
  correctly.
  """

  import Core.Utils.Pipeline
  alias Core.Utils.DomainExtractor
  @err_empty_domain {:error, "empty domain"}
  @err_invalid_domain {:error, "invalid domain"}

  @doc """
  Checks if a domain is valid according to IDNA rules and basic format requirements.
  """
  def valid_domain?(domain) when is_binary(domain) and byte_size(domain) > 0 do
    valid =
      domain
      |> DomainExtractor.extract_base_domain()
      |> ok(&DomainExtractor.clean_domain/1)
      |> ok(&Domainatrex.parse/1)

    case valid do
      {:ok, _} -> true
      _ -> false
    end
  end

  def valid_domain?(domain) when is_list(domain) do
    valid_domain?(to_string(domain))
  end

  def valid_domain?(nil), do: false
  def valid_domain?(""), do: false
  def valid_domain?(_), do: false

  @doc """
  Parses a domain into root domain and subdomain components.

  returns
  {:ok, %{domain: "customeros", tld: "ai", subdomain: "cos"}}
  or 
  {:error, "Cannot match: invalid domain"}
  """
  def parse_root_and_subdomain(domain) when is_binary(domain) do
    domain
    |> DomainExtractor.clean_domain()
    |> ok(&Domainatrex.parse/1)
  end

  def parse_root_and_subdomain(nil), do: @err_empty_domain
  def parse_root_and_subdomain(""), do: @err_empty_domain
  def parse_root_and_subdomain(_), do: @err_invalid_domain
end
