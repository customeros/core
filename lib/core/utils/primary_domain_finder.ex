defmodule Core.Utils.PrimaryDomainFinder do
  @moduledoc """
  Utilities for determining if a domain is a primary domain and finding redirect targets.

  A primary domain is defined as a domain that:
  - Has valid DNS records (A/AAAA records)
  - Does not have a CNAME record (indicating it's not an alias)
  - Is the root domain (no subdomain)
  - Does not redirect to another domain
  - Is directly accessible

  Note: MX records are not required as many legitimate websites use external email services
  or don't have email configured on their domain.

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

  @err_domain_not_reachable {:error, :domain_not_reachable}
  @err_empty_domain {:error, "empty domain"}
  @err_invalid_domain {:error, "invalid domain"}
  @err_invalid_ssl {:error, "ssl certificate error"}
  @err_dns_lookup_failed {:error, "dns lookup failed"}
  @err_circular_domain {:error, "circular domain reference"}
  @err_cannot_resolve_to_primary_domain {:error,
                                         :cannot_resolve_to_primary_domain}
  @err_platform_url_not_allowed {:error, "app/social media URL not allowed"}
  @err_adult_content_not_allowed {:error, "adult content domain not allowed"}

  # Configuration constants
  @max_retries 3
  @max_redirects 3

  # Regex patterns for platform/social media URLs that should be rejected
  @platform_url_patterns [
    # Social Media Platforms
    ~r/^(https?:\/\/)?(www\.)?facebook\.com\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?instagram\.com\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?twitter\.com\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?x\.com\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?linkedin\.com\/(in|company)\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?youtube\.com\/(channel|user|c)\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?tiktok\.com\/@[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?snapchat\.com\/add\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?pinterest\.com\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?reddit\.com\/r\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?discord\.com\/invite\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?telegram\.me\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?whatsapp\.com\/[^\/]+/i,

    # App Stores
    ~r/^(https?:\/\/)?(apps\.apple\.com|itunes\.apple\.com)\/[^\/]+/i,
    ~r/^(https?:\/\/)?(play\.google\.com|play\.google\.com\/store)\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?microsoft\.com\/en-us\/p\/[^\/]+/i,

    # E-commerce Platforms
    ~r/^(https?:\/\/)?(www\.)?amazon\.com\/[^\/]+\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?ebay\.com\/[^\/]+\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?etsy\.com\/shop\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?shopify\.com\/[^\/]+/i,

    # Professional Networks
    ~r/^(https?:\/\/)?(www\.)?behance\.net\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?dribbble\.com\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?github\.com\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?gitlab\.com\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?stackoverflow\.com\/users\/[^\/]+/i,

    # Content Platforms
    ~r/^(https?:\/\/)?(www\.)?medium\.com\/@[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?substack\.com\/@[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?patreon\.com\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?kickstarter\.com\/projects\/[^\/]+/i,

    # Other Platforms
    ~r/^(https?:\/\/)?(www\.)?fiverr\.com\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?upwork\.com\/[^\/]+\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?freelancer\.com\/[^\/]+\/[^\/]+/i,
    ~r/^(https?:\/\/)?(www\.)?99designs\.com\/[^\/]+\/[^\/]+/i
  ]

  # Adult content domains to be filtered out
  @adult_content_domains [
    # Major adult content sites
    "pornhub.com",
    "xvideos.com",
    "xhamster.com",
    "xnxx.com",
    "redtube.com",
    "youporn.com",
    "tube8.com",
    "spankbang.com",
    "txxx.com",
    "xmovies.com",
    "beeg.com",
    "thumbzilla.com",
    "pornhd.com",
    "drtuber.com",
    "sunporno.com",
    "porn.com",
    "sex.com",
    "xxx.com",
    "adult.com",
    "sexvideos.com",
    "pornmd.com",
    "tnaflix.com",
    "empflix.com",
    "keezmovies.com",
    "slutload.com",
    "bangbros.com",
    "brazzers.com",
    "realitykings.com",
    "naughtyamerica.com",
    "digitalplayground.com",
    "vivid.com",
    "playboy.com",
    "penthouse.com",
    "hustler.com",
    "adulttime.com",
    "mindgeek.com",
    "chaturbate.com",
    "livejasmin.com",
    "cam4.com",
    "camsoda.com",
    "stripchat.com",
    "bongacams.com",
    "myfreecams.com",
    "flirt4free.com",
    "streamate.com",
    "onlyfans.com",
    "fansly.com",
    "manyvids.com",
    "clips4sale.com",
    "pornpics.com",
    "sex.com",
    "xxxpics.com",
    "nudepics.com",
    "sexhub.com",
    "motherless.com",
    "upornia.com",
    "porntube.com",
    "freeones.com",
    "ixxx.com",
    "4tube.com",
    "gotporn.com",
    "porngo.com",
    "pornktube.com",
    "hqporner.com",
    "porntrex.com",
    "pornolab.net",
    "eporner.com",
    "ashemaletube.com",
    "shemalez.com",
    "tgirls.com",
    "ladyboy.com",
    "escort.com",
    "slixa.com",
    "eros.com",
    "adultsearch.com",
    "skipthegames.com",
    "megapersonals.com",
    "bedpage.com",
    "cityxguide.com",
    "tryst.link",
    "switter.at",
    "privatedelights.ch",
    "adultsearch.com",
    "escortdirectory.com",
    "fetlife.com",
    "adultfriendfinder.com",
    "ashley-madison.com",
    "seeking.com",
    "casualx.com",
    "fuckbook.com",
    "bangwithfriends.com",
    "quickflirt.com",
    "iwantu.com",
    "hornyhub.com",
    "sexmessenger.com",
    "hookuphangout.com",
    "easysex.com",
    "sexfinder.com",
    "hornywife.com",
    "milfhookup.com",
    "cougarlife.com",
    "fling.com",
    "naughtydate.com",
    "benaughty.com",
    "together2night.com",
    "instabang.com",
    "sexhookup.com",
    "wildbuddies.com",
    "dirtyroulette.com",
    "sexroulette.com",
    "camroulette.com",
    "sexcamhub.com",
    "pornchat.com",
    "sexchat.com",
    "adultchat.com",
    "freechat.com",
    "livesexchat.com",
    "webcamchat.com",
    "sexting.com"
  ]

  @adult_content_strings [
    "porn",
    "xxx",
    "sex",
    "adult",
    "nude",
    "naked",
    "escort",
    "strip",
    "webcam",
    "erotic",
    "fetish",
    "bdsm",
    "kink",
    "milf",
    "teen",
    "mature",
    "anal",
    "oral",
    "blow",
    "fuck",
    "cock",
    "dick",
    "pussy",
    "tits",
    "boobs",
    "ass",
    "butt",
    "horny",
    "naughty",
    "dirty",
    "slut",
    "whore",
    "bang",
    "kinky",
    "orgasm",
    "cum",
    "masturbat",
    "vibrator",
    "dildo",
    "hookup",
    "tranny",
    "fling",
    "affair",
    "cheat",
    "swing",
    "wife",
    "husband",
    "gay",
    "lesbian",
    "trans",
    "shemale",
    "ladyboy",
    "femboy",
    "sissy",
    "domina",
    "mistress",
    "slave",
    "submissive",
    "dominant",
    "bondage",
    "spank",
    "whip",
    "torture",
    "pain",
    "pleasure",
    "roleplay",
    "taboo",
    "sensual",
    "smut"
  ]

  @doc """
  Checks if a domain is a primary domain. It checks if current domain is redirecting to the primary domain.
  """
  def primary_domain?(url) do
    case get_primary_domain(url) do
      {:ok, primary_domain} ->
        if DomainExtractor.extract_base_domain(primary_domain) ==
             DomainExtractor.extract_base_domain(url) do
          true
        else
          false
        end

      _ ->
        false
    end
  end

  @doc """
  Gets the primary domain for a given domain.

  If the input domain is not primary, this function attempts to find
  the actual primary domain (e.g., root domain or redirect target).
  """
  def get_primary_domain(url)
      when is_binary(url) and byte_size(url) > 0 do
    OpenTelemetry.Tracer.with_span "primary_domain_finder.get_primary_domain" do
      OpenTelemetry.Tracer.set_attributes([{"param.url", url}])

      case Retry.with_delay(
             fn -> try_get_primary_domain(url) end,
             @max_retries,
             # Don't retry on SSL errors, they are not transient
             retry_if: fn
               @err_invalid_ssl -> false
               _ -> true
             end
           ) do
        {:ok, :no_primary_domain} ->
          @err_cannot_resolve_to_primary_domain

        {:ok, primary_domain} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.primary_domain", primary_domain}
          ])

          {:ok, String.downcase(primary_domain)}

        @err_invalid_ssl ->
          check_www(url)

        {:error, _reason} ->
          @err_cannot_resolve_to_primary_domain
      end
    end
  end

  def get_primary_domain(""), do: @err_empty_domain
  def get_primary_domain(nil), do: @err_empty_domain
  def get_primary_domain(_), do: @err_invalid_domain

  defp check_www(domain) do
    result =
      domain
      |> ok(&safe_clean_domain/1)
      |> ok(&UrlFormatter.to_https_www/1)
      |> ok(&check_domain_redirects/1)

    case result do
      {:ok, :no_redirect} -> {:ok, String.downcase(domain)}
      _ -> @err_cannot_resolve_to_primary_domain
    end
  end

  defp try_get_primary_domain(url) do
    with {:ok, clean_domain} <- safe_clean_domain(url) do
      follow_domain_chain(clean_domain, MapSet.new(), @max_redirects)
    end
  end

  defp follow_domain_chain(current_domain, visited, redirects_remaining) do
    Logger.info(
      "Following domain chain: #{current_domain}, visited: #{inspect(MapSet.to_list(visited))}, redirects remaining: #{redirects_remaining}"
    )

    case update_visited_domains(current_domain, visited) do
      {:ok, new_visited_set} ->
        current_domain
        |> primary_domain_check()
        |> ok(&valid_primary_domain?/1)
        |> continue_if_necessary(new_visited_set, redirects_remaining)

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

  defp safe_clean_domain(url) do
    case DomainExtractor.clean_domain(url) do
      cleaned when is_binary(cleaned) and cleaned != "" ->
        case adult_content_domain?(cleaned) do
          true -> @err_adult_content_not_allowed
          false -> {:ok, cleaned}
        end

      _ ->
        @err_invalid_domain
    end
  end

  defp adult_content_domain?(domain) when is_binary(domain) do
    normalized_domain = String.downcase(domain)

    exact_match =
      Enum.any?(@adult_content_domains, fn adult_domain ->
        normalized_domain == adult_domain or
          String.ends_with?(normalized_domain, ".#{adult_domain}")
      end)

    string_match =
      Enum.any?(@adult_content_strings, fn adult_string ->
        String.contains?(normalized_domain, adult_string)
      end)

    exact_match or string_match
  end

  defp primary_domain_check(url) do
    url
    |> prepare_domain()
    |> ok(&check_platform_url_validity/1)
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

  defp prepare_domain(url) do
    Logger.info("Preparing url #{url}")

    case UrlExpander.expand_short_url(url) do
      {:ok, expanded_url} ->
        {:ok, expanded_url}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_platform_url_validity(url) do
    Logger.info("Checking platform URL validity for #{url}")

    # Check if URL matches any of the platform/social media patterns
    is_platform_url =
      Enum.any?(@platform_url_patterns, fn pattern ->
        Regex.match?(pattern, url)
      end)

    if is_platform_url do
      Logger.warning("Platform/social media URL detected and rejected: #{url}")
      @err_platform_url_not_allowed
    else
      {:ok, url}
    end
  end

  defp check_domain_validity(domain) do
    Logger.info("Checking domain validity for #{domain}")

    case DomainValidator.valid_domain?(domain) do
      true ->
        case parse_domain(domain) do
          {:ok, {root, subdomain}} ->
            case root in UrlExpander.url_shorteners() do
              true -> @err_invalid_domain
              false -> {:ok, {domain, root, subdomain}}
            end

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
        @err_domain_not_reachable

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

  defp check_domain_redirects(url) when is_binary(url) do
    Logger.info("Checking url redirects for #{url}")

    case DomainIO.test_redirect(url) do
      {:ok, {:redirect, _headers}} ->
        {:ok, :redirect}

      {:ok, {:no_redirect}} ->
        {:ok, :no_redirect}

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
            dns_info.has_a

        {:ok, {domain, root, subdomain, is_primary}}

      {:error, _} ->
        @err_dns_lookup_failed
    end
  end

  defp determine_primary_domain_status({:redirects, is_primary, domain}),
    do: {:ok, {is_primary, domain}}

  defp determine_primary_domain_status({domain, root, subdomain, is_primary}) do
    Logger.info(
      "Determining primary domain status for #{domain}, root: #{root}, subdomain: #{subdomain}, is_primary: #{is_primary}"
    )

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
