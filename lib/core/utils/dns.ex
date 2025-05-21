defmodule Core.Utils.Dns do
  @moduledoc """
  """

  @doc """
  checks dns records for a domain and returns a dns struct.
  """
  def check_dns(domain) do
    %{mx: [], spf: "", cname: "", has_a: false, errors: []}
    |> check_a_records(domain)
    |> check_mx_records(domain)
    |> check_spf_records(domain)
    |> check_cname_records(domain)
  end

  defp check_a_records(dns, domain) do
    has_a = has_a_or_aaaa_record(domain)
    %{dns | has_a: has_a}
  end

  defp check_mx_records(dns, domain) do
    {mx, mx_err} = get_mx_records_for_domain(domain)

    errors =
      if mx_err,
        do: ["mx lookup error: #{mx_err}" | dns.errors],
        else: dns.errors

    %{dns | mx: mx, errors: errors}
  end

  defp check_spf_records(dns, domain) do
    {spf, spf_err} = get_spf_record(domain)

    errors =
      if spf_err,
        do: ["spf lookup error: #{spf_err}" | dns.errors],
        else: dns.errors

    %{dns | spf: spf, errors: errors}
  end

  defp check_cname_records(dns, domain) do
    {exists, cname} = get_cname_record(domain)
    cname_value = if exists, do: cname, else: ""

    %{dns | cname: cname_value}
  end

  @doc """
  gets mx records for a domain, sorted by priority.
  returns {mx_records, error}.
  """
  def get_mx_records_for_domain(domain) do
    domain
    |> String.to_charlist()
    |> lookup_mx_records()
    |> process_mx_records()
  end

  defp lookup_mx_records(domain_charlist) do
    :inet_res.lookup(domain_charlist, :in, :mx)
  end

  defp process_mx_records([]) do
    {[], "no mx records found"}
  end

  defp process_mx_records(records) when is_list(records) do
    sorted =
      records
      |> Enum.sort_by(fn {priority, _host} -> priority end)
      |> Enum.map(fn {_priority, host} ->
        host
        |> to_string()
        |> String.trim_trailing(".")
        |> String.downcase()
      end)

    {sorted, nil}
  end

  defp process_mx_records(_) do
    {[], "error looking up mx records"}
  end

  @doc """
  gets the spf record for a domain.
  returns {spf_record, error}.
  """
  def get_spf_record(domain) do
    domain
    |> lookup_txt_records()
    |> find_spf_record()
  end

  defp lookup_txt_records(domain) do
    case :inet_res.lookup(String.to_charlist(domain), :in, :txt) do
      [] -> {:error, "no txt records found"}
      records when is_list(records) -> {:ok, records}
      _ -> {:error, "error looking up txt records"}
    end
  end

  defp find_spf_record({:error, reason}), do: {"", reason}

  defp find_spf_record({:ok, records}) do
    spf = Enum.find_value(records, "", &extract_spf_record/1)

    if spf == "",
      do: {"", "no spf record found"},
      else: {spf, nil}
  end

  defp extract_spf_record(record) do
    record_str = Enum.map_join(record, "", &to_string/1)
    if String.starts_with?(record_str, "v=spf1"), do: record_str, else: false
  end

  @doc """
  gets the cname record for a domain if it exists.
  returns {exists, cname}.
  """
  def get_cname_record(domain) do
    domain
    |> String.to_charlist()
    |> lookup_cname_record()
    |> process_cname_record(domain)
  end

  defp lookup_cname_record(domain_charlist) do
    :inet_res.lookup(domain_charlist, :in, :cname)
  end

  defp process_cname_record([], _domain) do
    {false, ""}
  end

  defp process_cname_record([cname | _], domain) do
    cname_str =
      cname
      |> to_string()
      |> String.trim_trailing(".")

    # check if cname is different from input domain
    if cname_str != domain && "#{cname_str}." != domain do
      {true, cname_str}
    else
      {false, ""}
    end
  end

  defp process_cname_record(_, _domain) do
    {false, ""}
  end

  @doc """
  checks if a domain has a or aaaa records.
  """
  def has_a_or_aaaa_record(domain) do
    domain_charlist = String.to_charlist(domain)

    case :inet_res.lookup(domain_charlist, :in, :a) do
      [] -> has_aaaa_record(domain_charlist)
      _ -> true
    end
  end

  defp has_aaaa_record(domain_charlist) do
    case :inet_res.lookup(domain_charlist, :in, :aaaa) do
      [] -> false
      _ -> true
    end
  end
end
