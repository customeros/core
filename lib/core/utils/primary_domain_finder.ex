defmodule Core.Utils.PrimaryDomainFinder do
  @moduledoc """
  Utilities for determining if a domain is a primary domain and finding redirect targets.

  A primary domain is defined as a domain that:
  - Has valid DNS records (A/AAAA records and MX records)
  - Does not have a CNAME record (indicating it's not an alias)
  - Is the root domain (no subdomain)
  - Does not redirect to another domain
  - Is directly accessible

  This module provides functions to check these conditions and determine the primary
  domain status of any given domain.
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Core.Utils.Errors
  alias Finch.Response
  alias Core.Utils.Tracing
  alias Core.Utils.{DomainValidator, DomainExtractor, DnsResolver, UrlExpander}

  @doc """
  Checks if a domain is a primary domain.

  A primary domain must meet several criteria:
  - Valid TLD and domain format
  - Accessible via HTTP/HTTPS
  - Has DNS A/AAAA and MX records
  - No CNAME record (not an alias)
  - No external redirects
  - Is the root domain (no subdomain)
  """

  @spec primary_domain?(String.t()) ::
          {:ok, boolean()}
          | {:error, Core.Utils.Errors.domain_error()}
          | {:error, Core.Utils.Errors.dns_error()}

  def primary_domain?(domain)
      when is_binary(domain) and byte_size(domain) > 0 do
    case primary_domain_check(domain) do
      {:ok, {is_primary, _domain}} -> {:ok, is_primary}
      {:error, reason} -> Errors.error(reason)
    end
  end

  def primary_domain?(""), do: Errors.error(:domain_not_provided)
  def primary_domain?(nil), do: Errors.error(:domain_not_provided)
  def primary_domain?(_), do: Errors.error(:invalid_domain)

  @doc """
  Gets the primary domain for a given domain.

  If the input domain is not primary, this function attempts to find
  the actual primary domain (e.g., root domain or redirect target).
  Follows up to 3 redirects before erroring.
  """
  @spec get_primary_domain(String.t()) ::
          {:ok, String.t()}
          | {:error, Core.Utils.Errors.domain_error()}
          | {:error, Core.Utils.Errors.dns_error()}
  def get_primary_domain(domain)
      when is_binary(domain) and byte_size(domain) > 0 do
    OpenTelemetry.Tracer.with_span "primary_domain_finder.get_primary_domain" do
      OpenTelemetry.Tracer.set_attributes([{"domain", domain}])

      case follow_domain_chain(domain, MapSet.new(), 3) do
        {:ok, primary_domain} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.primary_domain", primary_domain}
          ])

          Tracing.ok()

          {:ok, primary_domain}

        {:error, reason} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.cause", inspect(reason)}
          ])

          {:error, reason}
      end
    end
  end

  def get_primary_domain(""), do: Errors.error(:domain_not_provided)
  def get_primary_domain(nil), do: Errors.error(:domain_not_provided)
  def get_primary_domain(_), do: Errors.error(:invalid_domain)

  defp follow_domain_chain(current_domain, visited, redirects_remaining) do
    cond do
      MapSet.member?(visited, current_domain) ->
        handle_error({:error, :circular_domain_reference})

      true ->
        new_visited = MapSet.put(visited, current_domain)

        with {:ok, {_is_primary, primary_domain}} <-
               primary_domain_check(current_domain),
             :ok <- validate_non_empty(primary_domain),
             :ok <- validate_suspicious_domain(primary_domain) do
          if String.downcase(primary_domain) == String.downcase(current_domain) do
            # Found stable domain - success!
            Tracing.ok()

            OpenTelemetry.Tracer.set_attributes([
              {"result.primary_domain", primary_domain}
            ])

            {:ok, primary_domain}
          else
            # Need to follow redirect
            if redirects_remaining > 0 do
              follow_domain_chain(
                primary_domain,
                new_visited,
                redirects_remaining - 1
              )
            else
              handle_error({:error, :too_many_redirects})
            end
          end
        else
          error -> handle_error(error)
        end
    end
  end

  defp validate_non_empty(""), do: {:error, :no_primary_domain}
  defp validate_non_empty(_), do: :ok

  defp handle_error({:error, reason}) do
    Errors.error(reason)
  end

  # Private functions

  # Validate if a domain is suspicious
  defp validate_suspicious_domain(domain) do
    case parse_domain(domain) do
      {:ok, {_root, subdomain}} ->
        cond do
          # Check if domain has at least 2 dots (is a subdomain) and matches the pattern ww followed by 1-3 digits and a dot
          subdomain != "" &&
            Enum.count(String.graphemes(domain), &(&1 == ".")) >= 2 &&
              Regex.match?(~r/^ww\d{1,3}\./, subdomain) ->
            {:error, :suspicious_domain}

          true ->
            :ok
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp domain_redirect_check(domain)
       when is_binary(domain) and byte_size(domain) > 0 do
    case safe_clean_domain(domain) do
      {:ok, cleaned_domain} ->
        # Try HTTPS first
        case check_redirect("https", cleaned_domain) do
          {:ok, result} ->
            handle_redirect_result(result, cleaned_domain)

          {:error, :cannot_resolve_domain} ->
            # If HTTPS fails to connect, try HTTP
            case check_redirect("http", cleaned_domain) do
              {:ok, result} -> handle_redirect_result(result, cleaned_domain)
              {:error, reason} -> {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper to safely clean domain and always return {:ok, cleaned_domain} or {:error, reason}
  defp safe_clean_domain(domain) do
    case DomainExtractor.clean_domain(domain) do
      cleaned when is_binary(cleaned) and cleaned != "" -> {:ok, cleaned}
      _ -> {:error, :invalid_domain}
    end
  end

  # Helper function to handle the redirect result
  defp handle_redirect_result({true, redirect_target}, _cleaned_domain),
    do: {:ok, {true, redirect_target}}

  defp handle_redirect_result({false, ""}, _cleaned_domain),
    do: {:ok, {false, ""}}

  defp primary_domain_check(domain) do
    with result <- prepare_domain(domain),
         result <- check_domain_validity(result),
         result <- check_domain_accessibility(result),
         result <- check_domain_redirects(result),
         result <- check_domain_dns(result),
         result <- determine_primary_domain_status(result) do
      result
    end
  end

  # Step 1: prepare domain by expanding shortlinks and cleaning
  defp prepare_domain(domain) do
    case UrlExpander.expand_short_url(domain) do
      {:ok, expanded_domain} ->
        cleaned_domain = DomainExtractor.clean_domain(expanded_domain)
        {:ok, cleaned_domain}
    end
  end

  # Step 2: check if the domain is valid
  defp check_domain_validity({:ok, domain}) do
    case DomainValidator.has_valid_tld?(domain) do
      true ->
        case parse_domain(domain) do
          {:ok, {root, _subdomain}} when root == "linktr.ee" ->
            Errors.error(:invalid_domain)

          {:ok, {root, subdomain}} ->
            {:valid, {domain, root, subdomain}}

          {:error, _} ->
            Errors.error(:invalid_domain)
        end

      false ->
        Errors.error(:invalid_domain)
    end
  end

  # Step 3: check if the domain is accessible
  defp check_domain_accessibility({:error, reason}), do: Errors.error(reason)

  defp check_domain_accessibility({:valid, {domain, root, subdomain}}) do
    case DomainValidator.check_connection(root) do
      {:ok, true} -> {:accessible, {domain, root, subdomain}}
      {:ok, false} -> Errors.error(:cannot_resolve_domain)
      {:error, reason} -> Errors.error(reason)
    end
  end

  # Step 4: check if the domain redirects
  defp check_domain_redirects({:error, reason}), do: {:error, reason}

  defp check_domain_redirects({:accessible, {domain, root, subdomain}}) do
    case domain_redirect_check(root) do
      {:ok, {true, redirect_target}} ->
        {:redirects, {false, redirect_target}}

      {:ok, {false, ""}} ->
        {:not_redirects, {domain, root, subdomain}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Step 5: check DNS records
  defp check_domain_dns({:error, reason}), do: {:error, reason}
  defp check_domain_dns({:redirects, result}), do: {:redirects, result}

  defp check_domain_dns({:not_redirects, {domain, root, subdomain}}) do
    case DnsResolver.get_dns(root) do
      {:ok, dns_info} ->
        is_primary =
          dns_info.cname == "" &&
            length(dns_info.mx) > 0 &&
            dns_info.has_a

        {:dns_checked, {domain, root, subdomain, is_primary}}

      {:error, _} ->
        Errors.error(:dns_lookup_failed)
    end
  end

  # Step 6: determine final primary domain status
  defp determine_primary_domain_status({:error, reason}), do: {:error, reason}

  defp determine_primary_domain_status({:redirects, {is_primary, domain}}),
    do: {:ok, {is_primary, domain}}

  defp determine_primary_domain_status(
         {:dns_checked, {domain, root, subdomain, is_primary}}
       ) do
    cond do
      is_primary && subdomain == "" ->
        {:ok, {true, domain}}

      is_primary ->
        {:ok, {false, root}}

      true ->
        {:ok, {false, ""}}
    end
  end

  # Helper function to parse domain
  defp parse_domain(domain) do
    case DomainValidator.parse_root_and_subdomain(domain) do
      {:ok, root, subdomain} -> {:ok, {root, subdomain}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_redirect(protocol, domain) do
    url = "#{protocol}://#{domain}"
    request = build_request(url)

    case make_request(request) do
      {:ok, {:redirect, headers}} ->
        process_redirect_location(headers, domain)

      {:ok, {:not_redirect}} ->
        {:ok, {false, ""}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_request(url) do
    Finch.build(:get, url, [
      {"user-agent",
       "mozilla/5.0 (windows nt 10.0; win64; x64) applewebkit/537.36 (khtml, like gecko) chrome/91.0.4472.124 safari/537.36"}
    ])
  end

  defp make_request(request) do
    try do
      case Finch.request(request, Core.Finch, receive_timeout: 5000) do
        {:ok, %Response{status: status, headers: headers}}
        when status >= 300 and status < 400 ->
          {:ok, {:redirect, headers}}

        {:ok, %Response{}} ->
          {:ok, {:not_redirect}}

        {:error, _} ->
          Errors.error(:cannot_resolve_domain)
      end
    rescue
      _ -> Errors.error(:cannot_resolve_domain)
    end
  end

  defp process_redirect_location(headers, original_domain) do
    location = find_location_header(headers)

    if external_redirect?(location) do
      extract_and_compare_domains(location, original_domain)
    else
      {:ok, {false, ""}}
    end
  end

  defp find_location_header(headers) do
    Enum.find_value(headers, "", fn
      {"location", value} -> value
      _ -> false
    end)
  end

  defp external_redirect?(location) do
    location != "" && !String.starts_with?(location, "/")
  end

  defp extract_and_compare_domains(location_url, original_domain) do
    try do
      with %URI{host: host} when is_binary(host) and host != "" <-
             URI.parse(location_url),
           {:ok, redirect_base_domain} <-
             DomainExtractor.extract_base_domain(host),
           false <-
             String.downcase(redirect_base_domain) ==
               String.downcase(original_domain) do
        {:ok, {true, redirect_base_domain}}
      else
        # Domains are the same
        true -> {:ok, {false, ""}}
        # Other error cases
        _ -> {:ok, {false, ""}}
      end
    rescue
      _ -> Errors.error(:cannot_resolve_domain)
    end
  end
end
