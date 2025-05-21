defmodule Core.Utils.DomainValidator do
  @moduledoc """
  Functions for domain parsing and validation using idna.
  """

  # Multi-level TLDs that we know about
  @known_multi_level_tlds [
    # Country-specific second-level domains
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
  This handles internationalized domain names properly.
  """
  def normalize_domain(domain) when is_binary(domain) do
    try do
      case :idna.encode(to_charlist(domain),
             uts46: true,
             std3_rules: true,
             transitional: false
           ) do
        {:ok, normalized} ->
          to_string(normalized)

        {:error, reason, _} ->
          {:error, reason}

        normalized when is_list(normalized) ->
          # Direct return of normalized domain as charlist
          to_string(normalized)

        _ ->
          {:error, "Unknown error during domain normalization"}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  def normalize_domain(domain) when is_list(domain) do
    try do
      case :idna.encode(domain,
             uts46: true,
             std3_rules: true,
             transitional: false
           ) do
        {:ok, normalized} ->
          to_string(normalized)

        {:error, reason, _} ->
          {:error, reason}

        normalized when is_list(normalized) ->
          # Direct return of normalized domain as charlist
          to_string(normalized)

        _ ->
          {:error, "Unknown error during domain normalization"}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  def normalize_domain(nil), do: nil
  def normalize_domain(_), do: nil

  @doc """
  Checks if a domain is valid according to IDNA rules.
  """
  def valid_domain?(nil), do: false

  def valid_domain?(domain) when is_binary(domain) do
    try do
      case :idna.encode(to_charlist(domain),
             uts46: true,
             std3_rules: true,
             transitional: false
           ) do
        {:ok, _} -> true
        {:error, _, _} -> false
        # Success case where result is returned directly
        encoded when is_list(encoded) -> true
        _ -> false
      end
    rescue
      # If encoding fails for any reason, domain is invalid
      _ -> false
    end
  end

  def valid_domain?(domain) when is_list(domain) do
    try do
      case :idna.encode(domain,
             uts46: true,
             std3_rules: true,
             transitional: false
           ) do
        {:ok, _} -> true
        {:error, _, _} -> false
        # Success case where result is returned directly
        encoded when is_list(encoded) -> true
        _ -> false
      end
    rescue
      # If encoding fails for any reason, domain is invalid
      _ -> false
    end
  end

  def valid_domain?(_), do: false

  @doc """
  Parses a domain into root domain and subdomain.
  Returns {:ok, root, subdomain} or {:error, reason}.
  """
  def parse_root_and_subdomain(domain) when is_binary(domain) do
    # First normalize the domain
    case normalize_domain(domain) do
      {:error, reason} ->
        {:error, reason}

      normalized_domain ->
        parts = String.split(normalized_domain, ".")

        if length(parts) < 2 do
          {:error, "Invalid domain format"}
        else
          # Check for known multi-level TLDs
          {root, subdomain} = determine_root_and_subdomain(parts)
          {:ok, root, subdomain}
        end
    end
  end

  def parse_root_and_subdomain(domain) when is_list(domain) do
    parse_root_and_subdomain(to_string(domain))
  end

  def parse_root_and_subdomain(_), do: {:error, "Invalid domain"}

  defp determine_root_and_subdomain(parts) do
    domain_parts = Enum.reverse(parts)

    # Check if it's a known multi-level TLD (e.g., co.uk)
    is_known_multi_level_tld =
      length(domain_parts) >= 3 &&
        Enum.join([Enum.at(domain_parts, 1), Enum.at(domain_parts, 0)], ".") in @known_multi_level_tlds

    if is_known_multi_level_tld do
      # It's a known multi-level TLD, use 3 parts for the root domain
      root =
        Enum.join(
          [
            Enum.at(domain_parts, 2),
            Enum.at(domain_parts, 1),
            Enum.at(domain_parts, 0)
          ],
          "."
        )

      subdomain_parts = Enum.drop(Enum.reverse(domain_parts), 3)

      subdomain =
        if Enum.empty?(subdomain_parts),
          do: "",
          else: Enum.join(subdomain_parts, ".")

      {root, subdomain}
    else
      # Handle regular 2-part TLD or fallback
      handle_regular_domain(domain_parts, parts)
    end
  end

  defp handle_regular_domain(domain_parts, original_parts) do
    if length(domain_parts) >= 2 do
      # Normal case with at least 2 parts
      root =
        Enum.join([Enum.at(domain_parts, 1), Enum.at(domain_parts, 0)], ".")

      subdomain_parts = Enum.drop(Enum.reverse(domain_parts), 2)

      subdomain =
        if Enum.empty?(subdomain_parts),
          do: "",
          else: Enum.join(subdomain_parts, ".")

      {root, subdomain}
    else
      # Fallback for single-part domain (unlikely)
      {Enum.join(original_parts, "."), ""}
    end
  end

  @doc """
  Checks if a domain has what appears to be a valid TLD.
  Uses IDNA for validation and a check against known TLD patterns.
  """
  def has_valid_tld?(nil), do: false

  def has_valid_tld?(domain) when is_binary(domain) do
    with true <- valid_domain?(domain),
         normalized_domain when is_binary(normalized_domain) <-
           normalize_domain(domain),
         true <- String.split(normalized_domain, ".") |> length() >= 2 do
      # Inside the body, we can do our final work
      tld = String.split(normalized_domain, ".") |> List.last()
      String.length(tld) >= 2 && String.match?(tld, ~r/^[a-z0-9]+$/)
    else
      _ -> false
    end
  end

  # Handle charlists by converting to binary first
  def has_valid_tld?(domain) when is_list(domain) do
    has_valid_tld?(to_string(domain))
  end

  def has_valid_tld?(_), do: false

  @doc """
  Extracts the registrable domain (the part users can register) from a URL or domain.
  """
  def registrable_domain(domain_or_url) when is_binary(domain_or_url) do
    # Remove protocol and path if present
    domain =
      domain_or_url
      |> String.replace(~r{^https?://}, "")
      |> String.split("/", parts: 2)
      |> List.first()

    case parse_root_and_subdomain(domain) do
      {:ok, root, _} -> root
      {:error, _} -> nil
    end
  end

  def registrable_domain(domain_or_url) when is_list(domain_or_url) do
    registrable_domain(to_string(domain_or_url))
  end

  def registrable_domain(_), do: nil
end
