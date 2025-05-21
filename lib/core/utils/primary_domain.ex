defmodule Core.Utils.PrimaryDomain do
  alias Finch.Response

  @doc """
  checks if a domain is a primary domain and returns appropriate information.
  returns a tuple {is_primary, domain} where:
  - is_primary: boolean indicating if it's a primary domain
  - domain: the primary domain if found, or empty string
  """
  def primary_domain_check(domain) do
    domain
    |> prepare_domain()
    |> check_domain_validity()
    |> check_domain_accessibility()
    |> check_domain_redirects()
    |> check_domain_dns()
    |> determine_primary_domain_status()
  end

  # step 1: prepare domain by expanding shortlinks and cleaning
  defp prepare_domain(domain) do
    {domain, expanded} = Core.Utils.UrlExpander.expand_short_url(domain)
    cleaned_domain = Core.Utils.Domain.clean_domain(domain)
    {cleaned_domain, expanded}
  end

  # step 2: check if the domain is valid
  defp check_domain_validity({domain, expanded}) do
    if Core.Utils.DomainValidator.has_valid_tld?(domain) do
      case parse_domain(domain) do
        {root, _subdomain} when root == "linktr.ee" ->
          {:invalid, {false, ""}}

        {root, subdomain} ->
          {:valid, {domain, root, subdomain, expanded}}

        _ ->
          {:invalid, {false, ""}}
      end
    else
      {:invalid, {false, ""}}
    end
  end

  # step 3: check if the domain is accessible
  defp check_domain_accessibility({:invalid, result}), do: {:invalid, result}

  defp check_domain_accessibility({:valid, {domain, root, subdomain, expanded}}) do
    if check_connection(root) do
      {:accessible, {domain, root, subdomain, expanded}}
    else
      {:invalid, {false, ""}}
    end
  end

  # step 4: check if the domain redirects
  defp check_domain_redirects({:invalid, result}), do: {:invalid, result}

  defp check_domain_redirects(
         {:accessible, {domain, root, subdomain, expanded}}
       ) do
    case domain_redirect_check(root) do
      {true, redirect_target} ->
        {:redirects, {false, redirect_target}}

      {false, _} ->
        {:not_redirects, {domain, root, subdomain, expanded}}
    end
  end

  # step 5: check dns records
  defp check_domain_dns({:invalid, result}), do: {:invalid, result}
  defp check_domain_dns({:redirects, result}), do: {:redirects, result}

  defp check_domain_dns({:not_redirects, {domain, root, subdomain, expanded}}) do
    dns_info = Core.Utils.Dns.check_dns(root)

    is_primary =
      dns_info.cname == "" &&
        length(dns_info.mx) > 0 &&
        dns_info.has_a

    {:dns_checked, {domain, root, subdomain, expanded, is_primary}}
  end

  # step 6: determine final primary domain status
  defp determine_primary_domain_status({:invalid, result}), do: result
  defp determine_primary_domain_status({:redirects, result}), do: result

  defp determine_primary_domain_status(
         {:dns_checked, {domain, root, subdomain, expanded, is_primary}}
       ) do
    cond do
      is_primary && subdomain == "" && !expanded ->
        {true, domain}

      is_primary ->
        {false, root}

      true ->
        {false, ""}
    end
  end

  # helper function to parse domain
  defp parse_domain(domain) do
    case Core.Utils.DomainValidator.parse_root_and_subdomain(domain) do
      {:ok, root, sub} -> {root, sub}
      {:error, _} -> {domain, ""}
    end
  end

  @doc """
  checks if a tcp connection can be established with the domain on ports 80 or 443.
  """
  def check_connection(domain) do
    ["80", "443"]
    |> Enum.any?(fn port ->
      domain
      |> String.to_charlist()
      |> establish_connection(String.to_integer(port))
    end)
  end

  defp establish_connection(domain_charlist, port) do
    case :gen_tcp.connect(domain_charlist, port, [], 1000) do
      {:ok, conn} ->
        :gen_tcp.close(conn)
        true

      {:error, _} ->
        false
    end
  end

  @doc """
  checks for domain redirects and returns the domain it redirects to, if any.
  returns {has_redirect, redirect_domain}.
  """
  def domain_redirect_check(domain) do
    domain = Core.Utils.Domain.clean_domain(domain)

    # try https first, then http if no redirect is found
    case check_redirect("https", domain) do
      {true, redirect_target} -> {true, redirect_target}
      _ -> check_redirect("http", domain)
    end
  end

  defp check_redirect(protocol, domain) do
    url = "#{protocol}://#{domain}"

    request = build_request(url)

    case make_request(request) do
      {:redirect, headers} -> process_redirect_location(headers, domain)
      _ -> {false, ""}
    end
  end

  defp build_request(url) do
    Finch.build(:get, url, [
      {"user-agent",
       "mozilla/5.0 (windows nt 10.0; win64; x64) applewebkit/537.36 (khtml, like gecko) chrome/91.0.4472.124 safari/537.36"}
    ])
  end

  defp make_request(request) do
    case Finch.request(request, Core.Finch, receive_timeout: 5000) do
      {:ok, %Response{status: status, headers: headers}}
      when status >= 300 and status < 400 ->
        {:redirect, headers}

      _ ->
        {:not_redirect, nil}
    end
  end

  defp process_redirect_location(headers, original_domain) do
    location = find_location_header(headers)

    if external_redirect?(location) do
      extract_and_compare_domains(location, original_domain)
    else
      {false, ""}
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
    with %URI{host: host} when is_binary(host) and host != "" <-
           URI.parse(location_url),
         {:ok, redirect_base_domain} <-
           Core.Utils.Domain.extract_base_domain(host),
         true <-
           String.downcase(redirect_base_domain) !=
             String.downcase(original_domain) do
      {true, redirect_base_domain}
    else
      # This matches when domains are the same
      true -> {false, ""}
      # This catches all other error cases
      _ -> {false, ""}
    end
  end
end
