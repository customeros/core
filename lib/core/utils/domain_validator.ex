defmodule Core.Utils.DomainValidator do
  @moduledoc """
  Functions for domain parsing and validation using IDNA standards.

  This module provides comprehensive domain validation, normalization, and parsing
  utilities. It handles internationalized domain names (IDN) and multi-level TLDs
  correctly.
  """

  alias Core.Utils.Errors

  # Multi-level TLDs
  @known_multi_level_tlds [
    "co.uk",
    "co.jp",
    "co.nz",
    "co.za",
    "co.kr",
    "co.id",
    "co.il",
    "co.th",
    "co.in",
    "com.au",
    "com.br",
    "com.cn",
    "com.mx",
    "com.tw",
    "com.hk",
    "com.sg",
    "com.tr",
    "com.ua",
    "com.ar",
    "com.ru",
    "or.jp",
    "ne.jp",
    "ac.uk",
    "ac.nz",
    "ac.jp",
    "org.uk",
    "gov.uk",
    "net.uk",
    "org.au",
    "id.au",
    "net.au",
    "asn.au",
    "com.de",
    "co.at",
    "or.at",
    "ac.at"
  ]

  @doc """
  Normalizes a domain using IDNA processing.

  This handles internationalized domain names properly and returns the ASCII
  representation of the domain.
  """
  @spec normalize_domain(String.t() | charlist()) ::
          String.t() | {:error, Core.Utils.Errors.domain_error()}
  def normalize_domain(domain) when is_binary(domain) do
    normalize_domain_impl(to_charlist(domain))
  end

  def normalize_domain(domain) when is_list(domain) do
    normalize_domain_impl(domain)
  end

  def normalize_domain(nil), do: Errors.error(:domain_not_provided)
  def normalize_domain(""), do: Errors.error(:domain_not_provided)
  def normalize_domain(_), do: Errors.error(:invalid_domain)

  defp normalize_domain_impl(domain_charlist) do
    try do
      case :idna.encode(domain_charlist,
             uts46: true,
             std3_rules: true,
             transitional: false
           ) do
        normalized when is_list(normalized) ->
          to_string(normalized)
      end
    rescue
      _e -> Errors.error(:unable_to_normalize_domain)
    end
  end

  @doc """
  Checks if a domain is valid according to IDNA rules and basic format requirements.

  A valid domain must:
  - Contain at least one dot
  - Be at least 3 characters long
  - Not start or end with a dot
  - Pass IDNA encoding validation
  """
  @spec valid_domain?(String.t() | charlist()) :: boolean()
  def valid_domain?(domain) when is_binary(domain) do
    String.contains?(domain, ".") and
      String.length(domain) >= 3 and
      not String.starts_with?(domain, ".") and
      not String.ends_with?(domain, ".") and
      idna_valid?(domain)
  end

  def valid_domain?(domain) when is_list(domain) do
    valid_domain?(to_string(domain))
  end

  def valid_domain?(nil), do: false
  def valid_domain?(""), do: false
  def valid_domain?(_), do: false

  defp idna_valid?(domain) when is_binary(domain) do
    # Pre-validate to catch invalid characters before IDNA validation
    if String.contains?(domain, ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]) do
      false
    else
      try do
        case :idna.encode(to_charlist(domain),
               uts46: true,
               std3_rules: true,
               transitional: false
             ) do
          encoded when is_list(encoded) -> true
        end
      rescue
        _ -> false
      end
    end
  end

  defp idna_valid?(_), do: false

  @doc """
  Parses a domain into root domain and subdomain components.

  Handles multi-level TLDs correctly (e.g., co.uk, com.au) and returns
  the registrable domain as the root.
  """
  @spec parse_root_and_subdomain(String.t() | charlist()) ::
          {:ok, String.t(), String.t()}
          | {:error, Core.Utils.Errors.domain_error()}
  def parse_root_and_subdomain(domain) when is_binary(domain) do
    case normalize_domain(domain) do
      {:error, reason} ->
        {:error, reason}

      normalized_domain ->
        parts = String.split(normalized_domain, ".")

        if length(parts) < 2 do
          Errors.error(:invalid_domain)
        else
          {root, subdomain} = determine_root_and_subdomain(parts)
          {:ok, root, subdomain}
        end
    end
  end

  def parse_root_and_subdomain(domain) when is_list(domain) do
    parse_root_and_subdomain(to_string(domain))
  end

  def parse_root_and_subdomain(nil), do: Errors.error(:domain_not_provided)
  def parse_root_and_subdomain(""), do: Errors.error(:domain_not_provided)
  def parse_root_and_subdomain(_), do: Errors.error(:invalid_domain)

  defp determine_root_and_subdomain(parts) do
    domain_parts = Enum.reverse(parts)

    # Check if it's a known multi-level TLD (e.g., co.uk)
    is_known_multi_level_tld =
      length(domain_parts) >= 3 &&
        Enum.join([Enum.at(domain_parts, 1), Enum.at(domain_parts, 0)], ".") in @known_multi_level_tlds

    if is_known_multi_level_tld do
      extract_multi_level_tld_parts(domain_parts)
    else
      extract_regular_domain_parts(domain_parts)
    end
  end

  defp extract_multi_level_tld_parts(domain_parts) do
    # For multi-level TLD, root is name + multi-level TLD (3 parts total)
    root = Enum.take(domain_parts, 3) |> Enum.reverse() |> Enum.join(".")

    subdomain_parts = Enum.drop(domain_parts, 3) |> Enum.reverse()

    subdomain =
      if Enum.empty?(subdomain_parts),
        do: "",
        else: Enum.join(subdomain_parts, ".")

    {root, subdomain}
  end

  defp extract_regular_domain_parts(domain_parts) do
    # For regular TLD, root is name + TLD (2 parts total)
    root = Enum.take(domain_parts, 2) |> Enum.reverse() |> Enum.join(".")

    subdomain_parts = Enum.drop(domain_parts, 2) |> Enum.reverse()

    subdomain =
      if Enum.empty?(subdomain_parts),
        do: "",
        else: Enum.join(subdomain_parts, ".")

    {root, subdomain}
  end

  @doc """
  Checks if a domain has a valid top-level domain (TLD).

  Validates both the domain format and ensures the TLD meets basic requirements
  (at least 2 characters, alphanumeric only).

  """
  @spec has_valid_tld?(String.t() | charlist()) :: boolean()
  def has_valid_tld?(domain) when is_binary(domain) do
    with true <- valid_domain?(domain),
         normalized_domain when is_binary(normalized_domain) <-
           normalize_domain(domain),
         parts when length(parts) >= 2 <- String.split(normalized_domain, ".") do
      tld = List.last(parts)
      String.length(tld) >= 2 && Regex.match?(~r/^[a-z0-9]+$/i, tld)
    else
      _ -> false
    end
  end

  def has_valid_tld?(domain) when is_list(domain) do
    has_valid_tld?(to_string(domain))
  end

  def has_valid_tld?(nil), do: false
  def has_valid_tld?(""), do: false
  def has_valid_tld?(_), do: false

  @doc """
  Extracts the registrable domain (the part users can register) from a URL or domain.

  This function strips protocols, paths, and subdomains to return just the
  registrable portion of the domain.

  """
  @spec registrable_domain(String.t() | charlist()) ::
          {:ok, String.t()} | {:error, Core.Utils.Errors.domain_error()}
  def registrable_domain(domain_or_url) when is_binary(domain_or_url) do
    # Remove protocol and path if present
    domain =
      domain_or_url
      |> String.replace(~r{^https?://}, "")
      |> String.split("/", parts: 2)
      |> List.first()

    case parse_root_and_subdomain(domain) do
      {:ok, root, _} -> {:ok, root}
      {:error, _} -> Errors.error(:invalid_domain)
    end
  end

  def registrable_domain(domain_or_url) when is_list(domain_or_url) do
    registrable_domain(to_string(domain_or_url))
  end

  def registrable_domain(""), do: Errors.error(:domain_not_provided)
  def registrable_domain(nil), do: Errors.error(:domain_not_provided)
  def registrable_domain(_), do: Errors.error(:invalid_domain)

  @doc """
  Validates a domain and returns a normalized result.

  Combines validation and normalization in a single function call.

  """
  @spec validate_domain(String.t() | charlist()) ::
          {:ok, String.t()} | {:error, Core.Utils.Errors.domain_error()}
  def validate_domain(domain) when is_binary(domain) or is_list(domain) do
    domain_str = if is_list(domain), do: to_string(domain), else: domain

    if valid_domain?(domain_str) do
      case normalize_domain(domain_str) do
        {:error, reason} -> {:error, reason}
        normalized -> {:ok, String.downcase(normalized)}
      end
    else
      Errors.error(:invalid_domain)
    end
  end

  def validate_domain(nil), do: Errors.error(:domain_not_provided)
  def validate_domain(""), do: Errors.error(:domain_not_provided)
  def validate_domain(_), do: Errors.error(:invalid_domain)

  @doc """
  Checks if a TCP connection can be established with the domain on ports 80 or 443.

  Tests connectivity to determine if a domain is accessible for HTTP/HTTPS traffic.
  """
  @spec check_connection(String.t()) ::
          {:ok, boolean()}
          | {:error, Core.Utils.Errors.domain_error()}
          | {:error, Core.Utils.Errors.dns_error()}
  def check_connection(domain)
      when is_binary(domain) and byte_size(domain) > 0 do
    try do
      result =
        [80, 443]
        |> Enum.any?(fn port ->
          domain
          |> String.to_charlist()
          |> establish_connection(port)
        end)

      {:ok, result}
    rescue
      _ -> Errors.error(:cannot_resolve_domain)
    end
  end

  def check_connection(""), do: Errors.error(:domain_not_provided)
  def check_connection(nil), do: Errors.error(:domain_not_provided)
  def check_connection(_), do: Errors.error(:invalid_domain)

  defp establish_connection(domain_charlist, port) do
    case :gen_tcp.connect(domain_charlist, port, [], 1000) do
      {:ok, conn} ->
        :gen_tcp.close(conn)
        true

      {:error, _} ->
        false
    end
  end
end
