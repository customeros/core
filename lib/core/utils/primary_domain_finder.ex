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

  import Core.Utils.Pipeline

  alias Core.Utils.{
    Retry,
    DomainIO,
    DnsResolver,
    UrlExpander,
    UrlFormatter,
    DomainExtractor,
    DomainValidator
  }

  @err_empty_domain {:error, "empty domain"}
  @err_invalid_domain {:error, "invalid domain"}
  @err_dns_lookup_failed {:error, "dns lookup failed"}
  @err_circular_domain {:error, "circular domain reference"}
  @err_cannot_resolve_to_primary_domain {:error,
                                         "cannot resolve to primary domain"}

  # Configuration constants
  @max_retries 5
  @max_redirects 3

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
  def primary_domain?(domain) do
    case primary_domain_check(domain) do
      {:ok, {is_primary, _domain}} -> is_primary
      _ -> false
    end
  end

  @doc """
  Gets the primary domain for a given domain.

  If the input domain is not primary, this function attempts to find
  the actual primary domain (e.g., root domain or redirect target).
  """
  def get_primary_domain(domain)
      when is_binary(domain) and byte_size(domain) > 0 do
    OpenTelemetry.Tracer.with_span "primary_domain_finder.get_primary_domain" do
      OpenTelemetry.Tracer.set_attributes([{"domain", domain}])

      case Retry.with_delay(
             fn -> try_get_primary_domain(domain) end,
             @max_retries
           ) do
        {:ok, :no_primary_domain} ->
          @err_cannot_resolve_to_primary_domain

        {:ok, primary_domain} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.primary_domain", primary_domain}
          ])

          {:ok, primary_domain}

        {:error, _reason} ->
          Retry.with_delay(
            fn -> try_get_primary_domain_https(domain) end,
            @max_retries
          )
      end
    end
  end

  def get_primary_domain(""), do: @err_empty_domain
  def get_primary_domain(nil), do: @err_empty_domain
  def get_primary_domain(_), do: @err_invalid_domain

  defp try_get_primary_domain(domain) do
    with {:ok, clean_domain} <- safe_clean_domain(domain) do
      follow_domain_chain(clean_domain, MapSet.new(), @max_redirects)
    end
  end

  defp try_get_primary_domain_https(domain) do
    case UrlFormatter.to_https(domain) do
      {:ok, https_domain} ->
        with {:ok, clean_domain} <- safe_clean_domain(https_domain) do
          follow_domain_chain(clean_domain, MapSet.new(), @max_redirects)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp follow_domain_chain(current_domain, visited, redirects_remaining) do
    Logger.info(
      "Following domain chain: #{current_domain}, visited: #{inspect(MapSet.to_list(visited))}, redirects remaining: #{redirects_remaining}"
    )

    with {:ok, new_visited_set} <-
           update_visited_domains(current_domain, visited) do
      current_domain
      |> primary_domain_check()
      |> ok(&valid_primary_domain?/1)
      |> continue_if_necessary(new_visited_set, redirects_remaining)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_visited_domains(domain, visited) do
    if MapSet.member?(visited, domain) do
      Logger.warning("Circular domain reference detected: #{domain}")
      @err_circular_domain
    else
      {:ok, MapSet.put(visited, domain)}
    end
  end

  defp safe_clean_domain(domain) do
    case DomainExtractor.clean_domain(domain) do
      cleaned when is_binary(cleaned) and cleaned != "" -> {:ok, cleaned}
      _ -> @err_invalid_domain
    end
  end

  defp primary_domain_check(domain) do
    domain
    |> prepare_domain()
    |> ok(&check_domain_validity/1)
    |> ok(&check_domain_accessibility/1)
    |> ok(&check_domain_redirects/1)
    |> ok(&check_domain_dns/1)
    |> ok(&determine_primary_domain_status/1)
  end

  defp valid_primary_domain?({false, domain}), do: {:ok, {false, domain}}

  defp valid_primary_domain?({_, ""}),
    do: @err_cannot_resolve_to_primary_domain

  defp valid_primary_domain?({true, domain}) do
    with true <- non_empty_domain?(domain),
         false <- suspicious_domain?(domain) do
      {:ok, {true, domain}}
    else
      _ -> {:ok, {false, domain}}
    end
  end

  defp continue_if_necessary({:error, reason}, _visited, _redirects),
    do: {:error, reason}

  defp continue_if_necessary({:ok, {is_primary, domain}}, visited, redirects) do
    Logger.info(
      "Continue if necessary: is_primary=#{is_primary}, domain=#{domain}, redirects=#{redirects}"
    )

    cond do
      is_primary ->
        {:ok, domain}

      domain == "" or redirects <= 0 ->
        {:ok, :no_primary_domain}

      true ->
        case safe_clean_domain(domain) do
          {:ok, clean_domain} ->
            follow_domain_chain(clean_domain, visited, redirects - 1)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp non_empty_domain?(""), do: false
  defp non_empty_domain?(_), do: true

  defp suspicious_domain?(domain)
       when is_binary(domain) and byte_size(domain) > 0 do
    case parse_domain(domain) do
      {:ok, parsed} -> suspicious_domain?(parsed)
      {:error, _} -> false
    end
  end

  defp suspicious_domain?({_root, subdomain}) do
    Logger.info("Is subdomain of #{subdomain} suspicious?")

    subdomain != "" &&
      Enum.count(String.graphemes(subdomain), &(&1 == ".")) >= 1 &&
      Regex.match?(~r/^w{2,3}\d{1,3}/, subdomain)
  end

  defp domain_redirect_check(domain)
       when is_binary(domain) and byte_size(domain) > 0 do
    case check_redirect("https", domain) do
      {:ok, result} ->
        handle_redirect_result(result, domain)

      @err_invalid_domain ->
        case check_redirect("http", domain) do
          {:ok, result} -> handle_redirect_result(result, domain)
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_redirect_result(result, domain) do
    Logger.info(
      "handle_redirect_result received: #{inspect(result)}, domain: #{domain}"
    )

    case result do
      {true, redirect_target} ->
        {:ok, {true, redirect_target}}

      {false, ""} ->
        {:ok, {false, ""}}

      other ->
        Logger.error("Unexpected redirect result: #{inspect(other)}",
          domain: domain,
          result: result
        )

        {:ok, {false, ""}}
    end
  end

  defp prepare_domain(domain) do
    Logger.info("Preparing domain #{domain}")

    case UrlExpander.expand_short_url(domain) do
      {:ok, expanded_domain} ->
        {:ok, expanded_domain}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_domain_validity(domain) do
    Logger.info("Checking domain validity for #{domain}")

    case DomainValidator.valid_domain?(domain) do
      true ->
        case parse_domain(domain) do
          {:ok, {root, _subdomain}} when root == "linktr.ee" ->
            @err_invalid_domain

          {:ok, {root, subdomain}} ->
            {:ok, {domain, root, subdomain}}

          {:error, _} ->
            @err_invalid_domain
        end

      false ->
        @err_invalid_domain
    end
  end

  defp check_domain_accessibility({domain, root, subdomain}) do
    Logger.info("Checking domain accessibility for #{domain}")

    case DomainIO.test_reachability(root) do
      {:ok, true} ->
        {:ok, {domain, root, subdomain}}

      {:ok, false} ->
        @err_invalid_domain

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_domain_redirects({domain, root, subdomain}) do
    Logger.info("Checking domain redirects for #{domain}")

    case domain_redirect_check(root) do
      {:ok, {true, redirect_target}} ->
        {:ok, {:redirects, false, redirect_target}}

      {:ok, {false, ""}} ->
        {:ok, {:no_redirects, domain, root, subdomain}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_domain_dns({:redirects, false, redirect_target}),
    do: {:ok, {:redirects, false, redirect_target}}

  defp check_domain_dns({:no_redirects, domain, root, subdomain}) do
    Logger.info("Checking domain DNS for #{domain}")

    case DnsResolver.get_dns(root) do
      {:ok, dns_info} ->
        is_primary =
          dns_info.cname == "" &&
            length(dns_info.mx) > 0 &&
            dns_info.has_a

        {:ok, {domain, root, subdomain, is_primary}}

      {:error, _} ->
        @err_dns_lookup_failed
    end
  end

  defp determine_primary_domain_status({:redirects, is_primary, domain}),
    do: {:ok, {is_primary, domain}}

  defp determine_primary_domain_status({domain, root, subdomain, is_primary}) do
    Logger.info("Determining primary domain status for #{domain}")

    cond do
      is_primary && subdomain == "" ->
        {:ok, {true, domain}}

      is_primary ->
        {:ok, {false, root}}

      true ->
        {:ok, {false, ""}}
    end
  end

  defp parse_domain(domain) do
    Logger.info("Parsing domain #{domain}")

    case DomainValidator.parse_root_and_subdomain(domain) do
      {:ok, %{domain: domain, tld: tld, subdomain: subdomain}} ->
        root = "#{domain}.#{tld}"
        {:ok, {root, subdomain}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_redirect(protocol, domain) do
    url = "#{protocol}://#{domain}"

    case DomainIO.test_redirect(url) do
      {:ok, {:redirect, headers}} ->
        process_redirect_location(headers, domain)

      {:ok, {:no_redirect}} ->
        {:ok, {false, ""}}

      {:error, reason} ->
        {:error, reason}
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
        true -> {:ok, {false, ""}}
        _ -> {:ok, {false, ""}}
      end
    rescue
      _ -> @err_invalid_domain
    end
  end
end
