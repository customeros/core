defmodule Core.Utils.DnsResolver do
  @moduledoc """
  DNS lookup utilities for domain validation and email configuration.

  This module provides functions to retrieve various DNS records (A, AAAA, MX, SPF, CNAME)
  for domains and returns structured information about their DNS configuration.
  """

  @err_empty_domain {:error, "empty domain"}
  @err_invalid_domain {:error, "invalid domain"}
  @err_no_records_found {:error, "no records found"}
  @err_dns_lookup_failed {:error, "dns lookup failed"}

  @type dns_result :: %{
          mx: [String.t()],
          spf: String.t(),
          cname: String.t(),
          has_a: boolean(),
          errors: [String.t()]
        }

  @doc """
  Gets DNS records for a domain and returns a DNS struct.

  Performs comprehensive DNS lookups including A/AAAA, MX, SPF, and CNAME records.
  Returns a map with all DNS information and any errors encountered during lookup.

  ## Examples

      iex> Core.Utils.Dns.get_dns("example.com")
      {:ok, %{
        mx: ["mail.example.com"],
        spf: "v=spf1 include:_spf.example.com ~all",
        cname: "",
        has_a: true,
        errors: []
      }}
  """

  def get_dns(domain) when is_binary(domain) and byte_size(domain) > 0 do
    try do
      result =
        %{mx: [], spf: "", cname: "", has_a: false, errors: []}
        |> check_a_records(domain)
        |> check_mx_records(domain)
        |> check_spf_records(domain)
        |> check_cname_records(domain)

      {:ok, result}
    rescue
      _ -> @err_dns_lookup_failed
    end
  end

  def get_dns(""), do: @err_empty_domain
  def get_dns(nil), do: @err_empty_domain
  def get_dns(_), do: @err_invalid_domain

  @doc """
  Gets MX records for a domain, sorted by priority.

  Looks up mail exchange records and returns them sorted by priority (lowest first).
  Hostnames are normalized (trailing dots removed, lowercased).

  """
  def get_mx_records(domain) when is_binary(domain) and byte_size(domain) > 0 do
    try do
      domain
      |> String.to_charlist()
      |> lookup_mx_records()
      |> process_mx_records()
    rescue
      _ -> @err_dns_lookup_failed
    end
  end

  def get_mx_records(""), do: @err_empty_domain
  def get_mx_records(nil), do: @err_empty_domain
  def get_mx_records(_), do: @err_invalid_domain

  @doc """
  Gets the SPF record for a domain.

  Searches TXT records for SPF (Sender Policy Framework) configuration.
  Returns the first SPF record found (starting with "v=spf1").
  """
  def get_spf_record(domain) when is_binary(domain) and byte_size(domain) > 0 do
    try do
      case lookup_txt_records(domain) do
        {:ok, records} ->
          case find_spf_in_records(records) do
            "" -> @err_no_records_found
            spf -> {:ok, spf}
          end

        {:error, _} ->
          @err_no_records_found
      end
    rescue
      _ -> @err_no_records_found
    end
  end

  def get_spf_record(""), do: @err_empty_domain
  def get_spf_record(nil), do: @err_empty_domain
  def get_spf_record(_), do: @err_invalid_domain

  @doc """
  Gets the CNAME record for a domain if it exists.

  Checks if the domain has a CNAME record pointing to a different hostname.
  """
  def get_cname_record(domain)
      when is_binary(domain) and byte_size(domain) > 0 do
    try do
      case domain |> String.to_charlist() |> lookup_cname_record() do
        [] ->
          @err_no_records_found

        [cname | _] ->
          cname_str = cname |> to_string() |> String.trim_trailing(".")

          # Check if CNAME is different from input domain
          if cname_str != domain && "#{cname_str}." != domain do
            {:ok, cname_str}
          else
            @err_no_records_found
          end
      end
    rescue
      _ -> @err_dns_lookup_failed
    end
  end

  def get_cname_record(""), do: @err_empty_domain
  def get_cname_record(nil), do: @err_empty_domain
  def get_cname_record(_), do: @err_invalid_domain

  @doc """
  Checks if a domain has A or AAAA records.

  Determines if the domain resolves to IPv4 (A) or IPv6 (AAAA) addresses.
  This indicates whether the domain has active hosting.
  """
  def has_a_or_aaaa_record(domain)
      when is_binary(domain) and byte_size(domain) > 0 do
    try do
      domain_charlist = String.to_charlist(domain)

      has_record =
        case :inet_res.lookup(domain_charlist, :in, :a) do
          [] -> has_aaaa_record(domain_charlist)
          _ -> true
        end

      {:ok, has_record}
    rescue
      _ -> @err_dns_lookup_failed
    end
  end

  def has_a_or_aaaa_record(""), do: @err_empty_domain
  def has_a_or_aaaa_record(nil), do: @err_empty_domain
  def has_a_or_aaaa_record(_), do: @err_invalid_domain

  # Private functions

  defp check_a_records(dns, domain) do
    case has_a_or_aaaa_record(domain) do
      {:ok, has_a} ->
        %{dns | has_a: has_a}

      {:error, _} ->
        %{dns | has_a: false, errors: ["a record lookup failed" | dns.errors]}
    end
  end

  defp check_mx_records(dns, domain) do
    case get_mx_records(domain) do
      {:ok, mx_records} -> %{dns | mx: mx_records}
      {:error, _} -> %{dns | mx: [], errors: ["mx lookup failed" | dns.errors]}
    end
  end

  defp check_spf_records(dns, domain) do
    case get_spf_record(domain) do
      {:ok, spf} ->
        %{dns | spf: spf}

      {:error, _} ->
        %{dns | spf: "", errors: ["spf lookup failed" | dns.errors]}
    end
  end

  defp check_cname_records(dns, domain) do
    case get_cname_record(domain) do
      {:ok, cname} -> %{dns | cname: cname}
      {:error, _} -> %{dns | cname: ""}
    end
  end

  defp lookup_mx_records(domain_charlist) do
    :inet_res.lookup(domain_charlist, :in, :mx)
  end

  defp process_mx_records([]), do: @err_no_records_found

  defp process_mx_records(records) when is_list(records) do
    sorted =
      records
      |> Enum.sort_by(fn {priority, _host} -> priority end)
      |> Enum.map(fn {_priority, host} ->
        host |> to_string() |> String.trim_trailing(".") |> String.downcase()
      end)

    {:ok, sorted}
  end

  defp lookup_txt_records(domain) do
    case :inet_res.lookup(String.to_charlist(domain), :in, :txt) do
      [] ->
        @err_no_records_found

      records when is_list(records) ->
        {:ok, records}
    end
  end

  defp find_spf_in_records(records) do
    Enum.find_value(records, "", &extract_spf_record/1)
  end

  defp extract_spf_record(record) do
    record_str = Enum.map_join(record, "", &to_string/1)
    if String.starts_with?(record_str, "v=spf1"), do: record_str, else: false
  end

  defp lookup_cname_record(domain_charlist) do
    :inet_res.lookup(domain_charlist, :in, :cname)
  end

  defp has_aaaa_record(domain_charlist) do
    case :inet_res.lookup(domain_charlist, :in, :aaaa) do
      [] -> false
      _ -> true
    end
  end
end
