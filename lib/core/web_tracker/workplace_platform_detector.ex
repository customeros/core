defmodule Core.WebTracker.WorkplacePlatformDetector do
  @moduledoc """
  Detects workplace platforms and business tools traffic.

  This module analyzes referrer URLs and query parameters to identify workplace 
  communication tools (Teams, Slack), CRM systems (Salesforce, HubSpot), 
  project management tools (Asana, Trello), and other business software platforms.
  """

  @doc """
  Checks if the referrer indicates workplace tool traffic.

  Returns true if referrer is from a recognized workplace platform.
  """
  def workplace?(referrer) do
    case get_platform(referrer) do
      {:ok, _platform} -> true
      :not_found -> false
    end
  end

  @doc """
  Gets the workplace platform from referrer or query params.

  Returns {:ok, :teams} or :not_found
  """
  def get_platform(referrer, query_params \\ nil) do
    case get_platform_from_referrer(referrer) do
      {:ok, platform} ->
        {:ok, platform}

      :not_found ->
        case parse_query_string(query_params) do
          {:ok, param_map} ->
            get_platform_from_params(param_map)

          {:error, _} ->
            :not_found
        end
    end
  end

  @workplace_domains %{
    # Communication & Collaboration
    "teams.microsoft.com" => :teams,
    "slack.com" => :slack,
    "zoom.us" => :zoom,
    "meet.google.com" => :google_meet,
    "webex.com" => :webex,
    "gotomeeting.com" => :gotomeeting,

    # CRM & Sales Tools
    "salesforce.com" => :salesforce,
    "hubspot.com" => :hubspot,
    "pipedrive.com" => :pipedrive,
    "zoho.com" => :zoho,

    # Customer Support
    "zendesk.com" => :zendesk,
    "intercom.com" => :intercom,
    "freshworks.com" => :freshworks,
    "freshdesk.com" => :freshworks,
    "drift.com" => :drift,

    # Project Management
    "asana.com" => :asana,
    "trello.com" => :trello,
    "monday.com" => :monday,
    "notion.so" => :notion,
    "notion.com" => :notion,
    "atlassian.net" => :jira,
    "clickup.com" => :clickup,
    "basecamp.com" => :basecamp,
    "airtable.com" => :airtable,

    # Marketing & Email Tools
    "mailchimp.com" => :mailchimp,
    "constantcontact.com" => :constant_contact,
    "campaignmonitor.com" => :campaign_monitor,
    "klaviyo.com" => :klaviyo,
    "marketo.com" => :marketo,

    # Document & File Sharing
    "drive.google.com" => :google_workspace,
    "docs.google.com" => :google_workspace,
    "sheets.google.com" => :google_workspace,
    "slides.google.com" => :google_workspace,
    "dropbox.com" => :dropbox,
    "box.com" => :box,
    "sharepoint.com" => :microsoft_office,
    "onedrive.com" => :microsoft_office,
    "cloud.microsoft" => :microsoft_office,

    # Enterprise Social
    "yammer.com" => :yammer,
    "workplace.com" => :meta_workplace
  }

  @domain_patterns [
    # Microsoft Teams (catches CDN and subdomain variations)
    {~r/teams.*\.microsoft\.com/, :teams},
    {~r/.*teams.*\.office\.net/, :teams},
    {~r/.*officeapps.*\.live\.com/, :microsoft_office},

    # Google docs
    {~r/^docs\.google\.com$/, :google_workspace},
    {~r/.*\.docs\.google\.com/, :google_workspace},
    {~r/^sheets\.google\.com$/, :google_workspace},
    {~r/.*\.sheets\.google\.com/, :google_workspace},
    {~r/^slides\.google\.com$/, :google_workspace},
    {~r/.*\.slides\.google\.com/, :google_workspace},
    {~r/^drive\.google\.com$/, :google_workspace},
    {~r/.*\.drive\.google\.com/, :google_workspace},
    {~r/^sites\.google\.com$/, :google_workspace},
    {~r/.*\.sites\.google\.com/, :google_workspace},
    {~r/^forms\.google\.com$/, :google_workspace},
    {~r/.*\.forms\.google\.com/, :google_workspace},

    # Salesforce patterns
    {~r/.*\.lightning\.force\.com/, :salesforce},
    {~r/.*\.force\.com/, :salesforce},
    {~r/.*\.salesforce\.com/, :salesforce},
    {~r/.*\.pardot\.com/, :salesforce},

    # Slack patterns
    {~r/.*\.slack\.com/, :slack},

    # HubSpot patterns
    {~r/.*\.hubspot\.com/, :hubspot},
    {~r/.*\.hs-sites\.com/, :hubspot},

    # Microsoft patterns
    {~r/.*\.sharepoint\.com/, :microsoft_office},
    {~r/.*\.onedrive\.com/, :microsoft_office},

    # Atlassian patterns
    {~r/.*\.atlassian\.net/, :jira},

    # Zendesk patterns
    {~r/.*\.zendesk\.com/, :zendesk},

    # Other workplace patterns
    {~r/.*\.workday\.com/, :workday},
    {~r/.*\.bamboohr\.com/, :bamboohr},
    {~r/.*\.greenhouse\.io/, :greenhouse},
    {~r/.*\.dropbox\.com/, :dropbox},
    {~r/.*\.box\.com/, :box},
    {~r/.*\.tableau\.com/, :tableau},
    {~r/.*\.klaviyo\.com/, :klaviyo},
    {~r/.*\.marketo\.com/, :marketo},
    {~r/.*\.mailchimp\.com/, :mailchimp},
    {~r/.*\.constantcontact\.com/, :constant_contact},
    {~r/.*\.campaignmonitor\.com/, :campaign_monitor},
    {~r/.*\.freshworks\.com/, :freshworks},
    {~r/.*\.freshdesk\.com/, :freshworks},
    {~r/.*\.pipedrive\.com/, :pipedrive},
    {~r/.*\.zoho\.com/, :zoho},
    {~r/.*\.asana\.com/, :asana},
    {~r/.*\.trello\.com/, :trello},
    {~r/.*\.monday\.com/, :monday},
    {~r/.*\.notion\./, :notion},
    {~r/.*\.clickup\.com/, :clickup},
    {~r/.*\.basecamp\.com/, :basecamp},
    {~r/.*\.airtable\.com/, :airtable},
    {~r/.*\.intercom\./, :intercom},
    {~r/.*\.drift\.com/, :drift},
    {~r/.*\.lever\.co/, :lever},
    {~r/.*\.adp\.com/, :adp},
    {~r/.*\.looker\.com/, :looker},
    {~r/.*\.yammer\.com/, :yammer},
    {~r/.*\.workplace\.com/, :meta_workplace}
  ]

  @utm_source_mapping %{
    # Communication platforms
    "teams" => :teams,
    "microsoft-teams" => :teams,
    "slack" => :slack,
    "zoom" => :zoom,

    # CRM platforms
    "salesforce" => :salesforce,
    "hubspot" => :hubspot,
    "pipedrive" => :pipedrive,
    "zoho" => :zoho,

    # Support platforms
    "zendesk" => :zendesk,
    "intercom" => :intercom,
    "freshworks" => :freshworks,

    # Project management
    "asana" => :asana,
    "trello" => :trello,
    "monday" => :monday,
    "notion" => :notion,
    "jira" => :jira,

    # Marketing tools
    "mailchimp" => :mailchimp,
    "klaviyo" => :klaviyo,
    "marketo" => :marketo
  }

  @platform_indicators %{
    # Salesforce indicators
    "sfdc_id" => :salesforce,
    "sfdcid" => :salesforce,

    # HubSpot indicators
    "hsCtaTracking" => :hubspot,
    "hs_email" => :hubspot,
    "_hsenc" => :hubspot,
    "_hsmi" => :hubspot,

    # Marketo indicators
    "mkt_tok" => :marketo,

    # Intercom indicators
    "intercom_id" => :intercom,

    # Zendesk indicators
    "zendesk_source" => :zendesk
  }

  # Private helper functions

  defp parse_query_string(query_params) when is_binary(query_params) do
    try do
      clean_params = String.trim_leading(query_params, "?")
      param_map = URI.decode_query(clean_params)
      {:ok, param_map}
    rescue
      _ -> {:error, :invalid_query_string}
    end
  end

  defp parse_query_string(params) when is_list(params) do
    try do
      param_map = params_to_map(params)
      {:ok, param_map}
    rescue
      _ -> {:error, :invalid_params_format}
    end
  end

  defp parse_query_string(_), do: {:error, :invalid_params_type}

  defp params_to_map(params) do
    params
    |> Enum.reduce(%{}, fn
      %{"name" => name, "value" => value}, acc
      when is_binary(name) and is_binary(value) ->
        Map.put(acc, name, String.trim(value))

      _, acc ->
        acc
    end)
  end

  defp get_platform_from_referrer(referrer) do
    case URI.parse(referrer) do
      %URI{host: nil} ->
        :not_found

      %URI{host: host} when is_binary(host) ->
        case check_domain_patterns(host) do
          :none ->
            case Core.Utils.DomainExtractor.extract_base_domain(referrer) do
              {:ok, domain} -> check_base_domain(domain)
              {:error, _} -> :not_found
            end

          platform ->
            {:ok, platform}
        end
    end
  end

  defp check_domain_patterns(host) do
    case Enum.find(@domain_patterns, fn {pattern, _platform} ->
           Regex.match?(pattern, host)
         end) do
      {_pattern, platform} -> platform
      nil -> :none
    end
  end

  defp check_base_domain(domain) do
    case Map.get(@workplace_domains, domain) do
      nil -> :not_found
      platform -> {:ok, platform}
    end
  end

  defp get_platform_from_params(param_map) do
    case detect_from_platform_indicators(param_map) do
      {:ok, platform} ->
        {:ok, platform}

      :not_found ->
        case detect_from_utm_params(param_map) do
          {:ok, platform} -> {:ok, platform}
          :not_found -> :not_found
        end
    end
  end

  defp detect_from_platform_indicators(param_map) do
    platform_param =
      Enum.find_value(@platform_indicators, fn {param_name, platform} ->
        if Map.has_key?(param_map, param_name), do: platform, else: nil
      end)

    case platform_param do
      nil -> :not_found
      platform -> {:ok, platform}
    end
  end

  defp detect_from_utm_params(param_map) do
    utm_source = Map.get(param_map, "utm_source", "") |> String.downcase()

    case Map.get(@utm_source_mapping, utm_source) do
      nil -> :not_found
      platform -> {:ok, platform}
    end
  end
end
