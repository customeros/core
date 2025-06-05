Application.ensure_all_started(:core)

defmodule IpIntelImporter do
  alias Core.WebTracker.IpIdentifier.IpIntelligence

  def run(ipdata_path, snitcher_path) do
    ipdata = get_ipdata(ipdata_path)
    get_snitcher_data_and_build_record(snitcher_path, ipdata)
  end

  def build_record(snitcher_row, ipdata) do
    ip_key = snitcher_row["ip_address"]
    ip_info = ipdata[ip_key]
    
    if ip_info do
      is_mobile = case ip_info["carrier_name"] do
        nil -> false
        "" -> false
        "null" -> false
        _ -> true
      end
      
      %{
        ip: snitcher_row["ip_address"],
        domain: snitcher_row["company_domain"],
        domain_source: :snitcher,
        is_mobile: is_mobile,
        city: ip_info["city"],
        region: ip_info["region"],
        country: ip_info["country_name"],
        has_threat: ip_info["is_threat"]
      }
    else
      %{
        ip: snitcher_row["ip_address"],
        domain: snitcher_row["company_domain"],
        domain_source: :snitcher,
        is_mobile: false,
        city: nil,
        region: nil,
        country: nil,
        has_threat: false
      }
    end
  end

  def get_ipdata(path) do
    ip_map = path  
    |> File.stream!()
    |> CSV.decode(headers: true)
    |> Stream.filter(&match?({:ok, _}, &1))  # Added missing underscore
    |> Stream.map(&elem(&1, 1))
    |> Stream.map(&parse_data_field/1)
    |> Enum.reduce(%{}, fn row, acc ->
      ip = row["ip"]
      Map.put(acc, ip, row)
    end)

    IO.puts("Loaded #{map_size(ip_map)} unique IPs")
    ip_map
  end

  def get_snitcher_data_and_build_record(path, ipdata) do
    path
    |> File.stream!()
    |> CSV.decode(headers: true)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Stream.map(&elem(&1, 1))
    |> Stream.map(&parse_snitcher_data_field/1)
    |> Stream.map(&build_record(&1, ipdata))  # Build the record for each row
    |> Stream.each(fn record ->
      IpIntelligence.create_if_not_exists(record)
      Process.sleep(100)
    end)
    |> Stream.run()  
  end

  defp parse_snitcher_data_field(row) do
    case Jason.decode(row["snitcher_data"]) do
      {:ok, parsed_data} ->
        # Merge the parsed data with the original row (excluding the raw "snitcher_data" field)
        row
        |> Map.delete("snitcher_data")
        |> Map.merge(flatten_snitcher_data(parsed_data))
      
      {:error, _} ->
        # If JSON parsing fails, return original row
        row
    end
  end

  defp flatten_snitcher_data(data) do
    %{
      # Top level fields
      "snitcher_ip" => data["ip"],
      "snitcher_domain" => data["domain"],
      "snitcher_type" => data["type"],
      
      # Company fields
      "company_name" => get_in(data, ["company", "name"]),
      "company_domain" => get_in(data, ["company", "domain"]),
      "company_website" => get_in(data, ["company", "website"]),
      "company_industry" => get_in(data, ["company", "industry"]),
      "company_founded_year" => get_in(data, ["company", "founded_year"]),
      "company_employee_range" => get_in(data, ["company", "employee_range"]),
      "company_annual_revenue" => get_in(data, ["company", "annual_revenue"]),
      "company_total_funding" => get_in(data, ["company", "total_funding"]),
      "company_location" => get_in(data, ["company", "location"]),
      "company_description" => get_in(data, ["company", "description"]),
      "company_phone" => get_in(data, ["company", "phone"]),
      
      # Company geo fields
      "company_country" => get_in(data, ["company", "geo", "country"]),
      "company_country_code" => get_in(data, ["company", "geo", "country_code"]),
      "company_state" => get_in(data, ["company", "geo", "state"]),
      "company_state_code" => get_in(data, ["company", "geo", "state_code"]),
      "company_postal_code" => get_in(data, ["company", "geo", "postal_code"]),
      "company_city" => get_in(data, ["company", "geo", "city"]),
      "company_street" => get_in(data, ["company", "geo", "street"]),
      "company_street_number" => get_in(data, ["company", "geo", "street_number"]),
      
      # Social profiles
      "crunchbase_handle" => get_in(data, ["company", "profiles", "crunchbase", "handle"]),
      "crunchbase_url" => get_in(data, ["company", "profiles", "crunchbase", "url"]),
      "linkedin_handle" => get_in(data, ["company", "profiles", "linkedin", "handle"]),
      "linkedin_url" => get_in(data, ["company", "profiles", "linkedin", "url"]),
      "facebook_handle" => get_in(data, ["company", "profiles", "facebook", "handle"]),
      "facebook_url" => get_in(data, ["company", "profiles", "facebook", "url"]),
      "twitter_handle" => get_in(data, ["company", "profiles", "twitter", "handle"]),
      "twitter_url" => get_in(data, ["company", "profiles", "twitter", "url"]),
      "instagram_handle" => get_in(data, ["company", "profiles", "instagram", "handle"]),
      "instagram_url" => get_in(data, ["company", "profiles", "instagram", "url"]),
      "youtube_handle" => get_in(data, ["company", "profiles", "youtube", "handle"]),
      "youtube_url" => get_in(data, ["company", "profiles", "youtube", "url"]),
      
      # GeoIP fields
      "geoip_country" => get_in(data, ["geoIP", "country"]),
      "geoip_country_code" => get_in(data, ["geoIP", "country_code"]),
      "geoip_city" => get_in(data, ["geoIP", "city"]),
      "geoip_state" => get_in(data, ["geoIP", "state"])
    }
  end

  defp parse_data_field(row) do
    case Jason.decode(row["data"]) do
      {:ok, parsed_data} ->
        # Merge the parsed data with the original row (excluding the raw "data" field)
        row
        |> Map.delete("data")
        |> Map.merge(flatten_nested_data(parsed_data))
      
      {:error, _} ->
        # If JSON parsing fails, return original row
        row
    end
  end

  defp flatten_nested_data(data) do
    # Flatten nested objects like asn, carrier, time_zone, threat
    %{
      "status_code" => data["status_code"],
      "message" => data["message"],
      "city" => data["city"],
      "region" => data["region"],
      "region_code" => data["region_code"],
      "region_type" => data["region_type"],
      "country_name" => data["country_name"],
      "country_code" => data["country_code"],
      "continent_name" => data["continent_name"],
      "continent_code" => data["continent_code"],
      "latitude" => data["latitude"],
      "longitude" => data["longitude"],
      # ASN fields
      "asn" => get_in(data, ["asn", "asn"]),
      "asn_name" => get_in(data, ["asn", "name"]),
      "asn_domain" => get_in(data, ["asn", "domain"]),
      "asn_route" => get_in(data, ["asn", "route"]),
      "asn_type" => get_in(data, ["asn", "type"]),
      # Carrier fields
      "carrier_name" => get_in(data, ["carrier", "name"]),
      "carrier_mcc" => get_in(data, ["carrier", "mcc"]),
      "carrier_mnc" => get_in(data, ["carrier", "mnc"]),
      # Time zone fields
      "timezone_name" => get_in(data, ["time_zone", "name"]),
      "timezone_abbr" => get_in(data, ["time_zone", "abbr"]),
      "timezone_offset" => get_in(data, ["time_zone", "offset"]),
      "timezone_is_dst" => get_in(data, ["time_zone", "is_dst"]),
      "timezone_current_time" => get_in(data, ["time_zone", "current_time"]),
      # Threat fields
      "is_tor" => get_in(data, ["threat", "is_tor"]),
      "is_vpn" => get_in(data, ["threat", "is_vpn"]),
      "is_icloud_relay" => get_in(data, ["threat", "is_icloud_relay"]),
      "is_proxy" => get_in(data, ["threat", "is_proxy"]),
      "is_datacenter" => get_in(data, ["threat", "is_datacenter"]),
      "is_anonymous" => get_in(data, ["threat", "is_anonymous"]),
      "is_known_attacker" => get_in(data, ["threat", "is_known_attacker"]),
      "is_known_abuser" => get_in(data, ["threat", "is_known_abuser"]),
      "is_threat" => get_in(data, ["threat", "is_threat"]),
      "is_bogon" => get_in(data, ["threat", "is_bogon"]),
      "blocklists" => get_in(data, ["threat", "blocklists"]),
      "count" => data["count"]
    }
  end
end

IpIntelImporter.run("../ipdata.csv", "../snitcher.csv")
