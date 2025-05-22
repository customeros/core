defmodule Core.External.Snitcher.Types do
  @moduledoc """
  Types for Snitcher API responses.
  """
  require Logger

  @type profile_info :: %{
    name: String.t(),
    handle: String.t(),
    url: String.t() | nil
  }

  @type social_profiles :: %{
    crunchbase: profile_info() | nil,
    linkedin: profile_info() | nil,
    facebook: profile_info() | nil,
    twitter: profile_info() | nil,
    instagram: profile_info() | nil,
    youtube: profile_info() | nil
  }

  @type geo_location :: %{
    country: String.t(),
    country_code: String.t(),
    state: String.t(),
    state_code: String.t() | nil,
    postal_code: String.t() | nil,
    city: String.t(),
    street: String.t() | nil,
    street_number: String.t() | nil
  }

  @type geo_ip :: %{
    country: String.t(),
    country_code: String.t(),
    city: String.t(),
    state: String.t()
  }

  @type location :: %{
    cityName: String.t(),
    regionName: String.t(),
    postalCode: String.t(),
    streetName: String.t(),
    streetNumber: String.t(),
    country: %{
      name: String.t(),
      iso2: String.t(),
      iso3: String.t()
    },
    rawLocation: String.t()
  }

  @type company_details :: %{
    name: String.t(),
    domain: String.t(),
    website: String.t(),
    industry: String.t(),
    founded_year: integer() | nil,
    employee_range: String.t(),
    annual_revenue: integer() | nil,
    total_funding: integer() | nil,
    location: String.t(),
    description: String.t(),
    phone: String.t(),
    geo: geo_location(),
    profiles: social_profiles() | nil
  }

  @type t :: %{
    ip: String.t(),
    domain: String.t(),
    type: String.t(),
    company: company_details() | nil,
    geoIP: geo_ip()
  }

  @doc """
  Parses a JSON response from Snitcher into our type structure.
  """
  def parse_response(%{
        "ip" => ip,
        "domain" => domain,
        "type" => type,
        "company" => company,
        "geoIP" => geoIP
      }) do
    {:ok,
     %{
       ip: ip,
       domain: domain,
       type: type,
       company: parse_company(company),
       geoIP: parse_geo_ip(geoIP)
     }}
  end

  def parse_response(%{
        "ip" => ip,
        "domain" => domain,
        "type" => type,
        "geoIP" => geoIP
      }) do
    {:ok,
     %{
       ip: ip,
       domain: domain,
       type: type,
       company: nil,
       geoIP: parse_geo_ip(geoIP)
     }}
  end

  def parse_response(data) do
    Logger.error("Invalid Snitcher response format. Expected keys: [ip, domain, type, geoIP], got: #{inspect(Map.keys(data))}. Full response: #{inspect(data, pretty: true, limit: :infinity)}")
    {:error, :invalid_response}
  end

  defp parse_company(nil), do: nil

  defp parse_company(%{
         "name" => name,
         "domain" => domain,
         "website" => website,
         "industry" => industry,
         "founded_year" => founded_year,
         "employee_range" => employee_range,
         "annual_revenue" => annual_revenue,
         "total_funding" => total_funding,
         "location" => location,
         "description" => description,
         "phone" => phone,
         "geo" => geo,
         "profiles" => profiles
       }) do
    %{
      name: name,
      domain: domain,
      website: website,
      industry: industry,
      founded_year: parse_integer(founded_year),
      employee_range: employee_range,
      annual_revenue: parse_integer(annual_revenue),
      total_funding: parse_integer(total_funding),
      location: location,
      description: description,
      phone: phone,
      geo: parse_geo(geo),
      profiles: parse_profiles(profiles)
    }
  end

  defp parse_company(data) do
    Logger.error("Invalid company data format", %{
      expected_keys: [
        "name", "domain", "website", "industry", "founded_year",
        "employee_range", "annual_revenue", "total_funding",
        "location", "description", "phone", "geo", "profiles"
      ],
      received_keys: Map.keys(data),
      data: inspect(data, pretty: true)
    })
    nil
  end

  defp parse_geo_ip(%{
         "country" => country,
         "country_code" => country_code,
         "city" => city,
         "state" => state
       }) do
    %{
      country: country,
      country_code: country_code,
      city: city,
      state: state
    }
  end

  defp parse_geo_ip(data) do
    Logger.error("Invalid geoIP data format", %{
      expected_keys: ["country", "country_code", "city", "state"],
      received_keys: Map.keys(data),
      data: inspect(data, pretty: true)
    })
    %{
      country: "",
      country_code: "",
      city: "",
      state: ""
    }
  end

  defp parse_geo(%{
         "country" => country,
         "country_code" => country_code,
         "state" => state,
         "state_code" => state_code,
         "postal_code" => postal_code,
         "city" => city,
         "street" => street,
         "street_number" => street_number
       }) do
    %{
      country: country,
      country_code: country_code,
      state: state,
      state_code: state_code,
      postal_code: postal_code,
      city: city,
      street: street,
      street_number: street_number
    }
  end

  defp parse_geo(data) do
    Logger.error("Invalid geo data format", %{
      expected_keys: ["country", "country_code", "state", "state_code", "postal_code", "city", "street", "street_number"],
      received_keys: Map.keys(data),
      data: inspect(data, pretty: true)
    })
    %{
      country: "",
      country_code: "",
      state: "",
      state_code: nil,
      postal_code: nil,
      city: "",
      street: nil,
      street_number: nil
    }
  end

  defp parse_profiles(%{
         "crunchbase" => crunchbase,
         "linkedin" => linkedin,
         "facebook" => facebook,
         "twitter" => twitter,
         "instagram" => instagram,
         "youtube" => youtube
       }) do
    %{
      crunchbase: parse_profile(crunchbase),
      linkedin: parse_profile(linkedin),
      facebook: parse_profile(facebook),
      twitter: parse_profile(twitter),
      instagram: parse_profile(instagram),
      youtube: parse_profile(youtube)
    }
  end

  defp parse_profiles(data) do
    Logger.error("Invalid profiles data format", %{
      expected_keys: ["crunchbase", "linkedin", "facebook", "twitter", "instagram", "youtube"],
      received_keys: Map.keys(data),
      data: inspect(data, pretty: true)
    })
    nil
  end

  defp parse_profile(%{"name" => name, "handle" => handle, "url" => url}) do
    %{
      name: name,
      handle: handle,
      url: if(is_binary(url), do: url, else: nil)
    }
  end

  defp parse_profile(data) do
    Logger.error("Invalid profile data format", %{
      expected_keys: ["name", "handle", "url"],
      received_keys: Map.keys(data),
      data: inspect(data, pretty: true)
    })
    nil
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end
  defp parse_integer(value) do
    Logger.error("Invalid integer value", %{
      value: inspect(value),
      type: inspect(value.__struct__)
    })
    nil
  end
end
