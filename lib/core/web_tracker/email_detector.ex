defmodule Core.WebTracker.EmailDetector do
  @moduledoc """
  Detects email platform traffic and distinguishes between marketing emails and personal email shares.

  This module analyzes referrer URLs and query parameters to identify email service 
  providers (Mailchimp, Klaviyo, Gmail, etc.) and determine whether traffic comes 
  from marketing email campaigns, transactional emails, or personal email shares.
  """

  alias Core.Utils.DomainExtractor

  # Mobile email app referrers
  @mobile_email_apps %{
    "android-app://com.google.android.gm" => :gmail,
    "android-app://com.microsoft.office.outlook" => :outlook,
    "android-app://com.yahoo.mobile.client.android.mail" => :yahoo_mail,
    "android-app://com.apple.mobilemail" => :icloud,
    "android-app://com.aol.mobile.aolapp" => :aol,
    "android-app://ch.protonmail.android" => :protonmail,
    "ios-app://1176895641" => :outlook,
    "ios-app://310633997" => :whatsapp,
    "ios-app://1489321253" => :protonmail
  }

  # UTM medium values that indicate email traffic
  @email_mediums [
    "email",
    "newsletter",
    "email-newsletter",
    "email_newsletter",
    "mail",
    "e-mail",
    "automated-email",
    "automated_email",
    "drip",
    "nurture",
    "welcome-series",
    "welcome_series",
    "digest",
    "announcement",
    "update"
  ]

  # UTM medium values specific to marketing emails
  @marketing_email_mediums [
    "email",
    "newsletter",
    "email-newsletter",
    "email_newsletter",
    "promotional-email",
    "promotional_email",
    "marketing-email",
    "marketing_email",
    "campaign",
    "blast",
    "drip",
    "nurture",
    "welcome-series",
    "welcome_series"
  ]

  # UTM medium values specific to transactional emails
  @transactional_email_mediums [
    "transactional",
    "transactional-email",
    "transactional_email",
    "notification",
    "alert",
    "receipt",
    "confirmation",
    "welcome",
    "password-reset",
    "password_reset",
    "account-verification",
    "account_verification",
    "order-confirmation",
    "order_confirmation",
    "shipping-notification",
    "shipping_notification"
  ]

  # Personal email platforms
  @personal_email_platforms [
    :gmail,
    :outlook,
    :yahoo_mail,
    :hotmail,
    :icloud,
    :aol,
    :protonmail
  ]

  # Marketing ESP platforms
  @marketing_esp_platforms [
    :mailchimp,
    :constant_contact,
    :campaign_monitor,
    :klaviyo,
    :aweber,
    :getresponse,
    :activecampaign,
    :convertkit,
    :drip,
    :sendinblue,
    :mailerlite
  ]

  # Transactional email platforms
  @transactional_platforms [
    :sendgrid,
    :mailgun,
    :mandrill,
    :ses,
    :postmark,
    :sparkpost,
    :mailjet
  ]

  # Campaign indicators in UTM parameters
  @campaign_indicators [
    "campaign",
    "promo",
    "sale",
    "offer",
    "discount",
    "newsletter",
    "announcement",
    "launch",
    "webinar",
    "event"
  ]

  # Transactional keywords
  @transactional_keywords [
    "welcome",
    "confirmation",
    "receipt",
    "invoice",
    "password",
    "reset",
    "verification",
    "activate",
    "shipping",
    "delivery",
    "order",
    "payment",
    "account",
    "notification",
    "alert",
    "reminder"
  ]

  # Generic email tracking parameters
  @generic_email_tracking_params [
    "email_id",
    "message_id",
    "subscriber_id",
    "list_id",
    "campaign_id",
    "tracking_id",
    "mail_id",
    "newsletter_id",
    "broadcast_id"
  ]

  @doc """
  Checks if the referrer and query params indicate email traffic.

  Returns true if traffic appears to come from an email source.
  """
  def email_traffic?(referrer, query_params) do
    cond do
      is_mobile_email_app?(referrer) -> true
      has_email_utm_medium?(query_params) -> true
      has_email_referrer?(referrer) -> true
      has_email_tracking_params?(query_params) -> true
      true -> false
    end
  end

  @doc """
  Checks if the traffic is from a marketing email campaign.

  Returns true if email contains marketing/campaign indicators.
  """
  def marketing_email?(referrer, query_params) do
    case parse_query_string(query_params) do
      {:ok, param_map} ->
        utm_medium = Map.get(param_map, "utm_medium", "") |> String.downcase()

        cond do
          utm_medium in @marketing_email_mediums -> true
          has_marketing_email_referrer?(referrer) -> true
          has_marketing_tracking_params?(param_map) -> true
          has_campaign_indicators?(param_map) -> true
          true -> false
        end

      {:error, _} ->
        has_marketing_email_referrer?(referrer)
    end
  end

  @doc """
  Checks if the traffic is from a transactional email.

  Returns true if email appears to be transactional (receipts, notifications, etc.).
  """
  def transactional_email?(referrer, query_params) do
    case parse_query_string(query_params) do
      {:ok, param_map} ->
        utm_medium = Map.get(param_map, "utm_medium", "") |> String.downcase()

        utm_campaign =
          Map.get(param_map, "utm_campaign", "") |> String.downcase()

        cond do
          utm_medium in @transactional_email_mediums -> true
          has_transactional_keywords?(utm_campaign) -> true
          has_transactional_referrer?(referrer) -> true
          true -> false
        end

      {:error, _} ->
        has_transactional_referrer?(referrer)
    end
  end

  @doc """
  Checks if traffic is from personal email sharing (Gmail, Outlook, etc.).

  Returns true if traffic appears to be from personal email clients.
  """
  def personal_email_share?(referrer, query_params) do
    case get_platform_from_referrer(referrer) do
      {:ok, platform} when platform in @personal_email_platforms ->
        # Only consider it personal if no marketing indicators
        not marketing_email?(referrer, query_params)

      _ ->
        false
    end
  end

  @doc """
  Gets the email platform from referrer or query params.

  Returns {:ok, :mailchimp} or :not_found
  """
  def get_platform(referrer, query_params \\ nil) do
    cond do
      is_mobile_email_app?(referrer) ->
        {:ok, get_mobile_email_platform(referrer)}

      true ->
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
  end

  @doc """
  Gets the email platform category.

  Returns the category type like :esp, :personal_email, :transactional, etc.
  """
  def get_platform_category(platform) do
    case platform do
      # Email Service Providers (Marketing)
      platform
      when platform in [
             :mailchimp,
             :constant_contact,
             :campaign_monitor,
             :klaviyo,
             :aweber,
             :getresponse,
             :activecampaign,
             :convertkit,
             :drip,
             :sendinblue,
             :mailerlite
           ] ->
        :esp

      # Transactional Email Services
      platform
      when platform in [
             :sendgrid,
             :mailgun,
             :mandrill,
             :ses,
             :postmark,
             :sparkpost,
             :mailjet
           ] ->
        :transactional

      # Personal Email Clients
      platform
      when platform in [
             :gmail,
             :outlook,
             :yahoo_mail,
             :hotmail,
             :icloud,
             :aol,
             :protonmail
           ] ->
        :personal_email

      # Enterprise Email
      platform when platform in [:office365, :google_workspace, :exchange] ->
        :enterprise_email

      # Marketing Automation
      platform
      when platform in [
             :marketo,
             :pardot,
             :hubspot_email,
             :salesforce_marketing
           ] ->
        :marketing_automation

      _ ->
        :other_email
    end
  end

  @email_domains %{
    # Major Email Service Providers (ESPs)
    "mailchimp.com" => :mailchimp,
    "us1.campaign-archive.com" => :mailchimp,
    "us2.campaign-archive.com" => :mailchimp,
    "us3.campaign-archive.com" => :mailchimp,
    "us4.campaign-archive.com" => :mailchimp,
    "us5.campaign-archive.com" => :mailchimp,
    "us6.campaign-archive.com" => :mailchimp,
    "click.mailchimp.com" => :mailchimp,
    "constantcontact.com" => :constant_contact,
    "click.constantcontact.com" => :constant_contact,
    "campaignmonitor.com" => :campaign_monitor,
    "click.campaignmonitor.com" => :campaign_monitor,
    "klaviyo.com" => :klaviyo,
    "links.klaviyo.com" => :klaviyo,
    "email.klaviyo.com" => :klaviyo,
    "aweber.com" => :aweber,
    "clicks.aweber.com" => :aweber,
    "email.aweber.com" => :aweber,
    "getresponse.com" => :getresponse,
    "click.getresponse.com" => :getresponse,
    "activecampaign.com" => :activecampaign,
    "click.activecampaign.com" => :activecampaign,
    "convertkit.com" => :convertkit,
    "email.convertkit.com" => :convertkit,
    "click.convertkit.com" => :convertkit,
    "drip.com" => :drip,
    "links.drip.com" => :drip,
    "sendinblue.com" => :sendinblue,
    "click.sendinblue.com" => :sendinblue,
    "mailerlite.com" => :mailerlite,
    "click.mailerlite.com" => :mailerlite,

    # Transactional Email Services
    "sendgrid.com" => :sendgrid,
    "sendgrid.net" => :sendgrid,
    "click.sendgrid.net" => :sendgrid,
    "mailgun.com" => :mailgun,
    "mailgun.org" => :mailgun,
    "click.mailgun.com" => :mailgun,
    "mandrill.com" => :mandrill,
    "mandrillapp.com" => :mandrill,
    "amazonses.com" => :ses,
    "email.amazonses.com" => :ses,
    "postmarkapp.com" => :postmark,
    "click.postmarkapp.com" => :postmark,
    "sparkpost.com" => :sparkpost,
    "click.sparkpost.com" => :sparkpost,
    "mailjet.com" => :mailjet,
    "click.mailjet.com" => :mailjet,

    # Personal Email Clients
    "gmail.com" => :gmail,
    "outlook.com" => :outlook,
    "hotmail.com" => :hotmail,
    "live.com" => :outlook,
    "msn.com" => :outlook,
    "yahoo.com" => :yahoo_mail,
    "mail.yahoo.com" => :yahoo_mail,
    "icloud.com" => :icloud,
    "me.com" => :icloud,
    "aol.com" => :aol,
    "mail.aol.com" => :aol,
    "protonmail.com" => :protonmail,
    "proton.me" => :protonmail,

    # Enterprise Email
    "outlook.office365.com" => :office365,
    "outlook.office.com" => :office365,
    "mail.google.com" => :google_workspace,

    # Marketing Automation
    "marketo.com" => :marketo,
    "click.marketo.com" => :marketo,
    "pardot.com" => :pardot,
    "click.pardot.com" => :pardot,
    "hubspot.com" => :hubspot_email,
    "click.hubspot.com" => :hubspot_email
  }

  @domain_patterns [
    # Mailchimp patterns
    {~r/.*\.campaign-archive\.com$/, :mailchimp},
    {~r/.*\.mailchimp\.com$/, :mailchimp},

    # Klaviyo patterns
    {~r/.*\.klaviyo\.com$/, :klaviyo},

    # Constant Contact patterns
    {~r/.*\.constantcontact\.com$/, :constant_contact},

    # Campaign Monitor patterns
    {~r/.*\.campaignmonitor\.com$/, :campaign_monitor},

    # AWeber patterns
    {~r/.*\.aweber\.com$/, :aweber},

    # ConvertKit patterns
    {~r/.*\.convertkit\.com$/, :convertkit},

    # SendGrid patterns
    {~r/.*\.sendgrid\.net$/, :sendgrid},

    # Mailgun patterns
    {~r/.*\.mailgun\.com$/, :mailgun},
    {~r/.*\.mailgun\.org$/, :mailgun},

    # Marketo patterns
    {~r/.*\.marketo\.com$/, :marketo},

    # Pardot patterns
    {~r/.*\.pardot\.com$/, :pardot},

    # HubSpot patterns
    {~r/.*\.hubspot\.com$/, :hubspot_email},

    # General ESP patterns
    {~r/click\..*/, :generic_esp},
    {~r/email\..*/, :generic_esp},
    {~r/mail\..*/, :generic_esp},
    {~r/link\..*/, :generic_esp},
    {~r/links\..*/, :generic_esp}
  ]

  # Platform-specific tracking parameters
  @email_tracking_params %{
    # Mailchimp
    "mc_cid" => :mailchimp,
    "mc_eid" => :mailchimp,

    # Klaviyo  
    "_ke" => :klaviyo,
    "kx" => :klaviyo,

    # Constant Contact
    "cc_id" => :constant_contact,

    # SendGrid
    "sg_id" => :sendgrid,

    # Campaign Monitor
    "cm_id" => :campaign_monitor,

    # AWeber
    "aweber_id" => :aweber,

    # ConvertKit
    "ck_subscriber_id" => :convertkit,

    # ActiveCampaign
    "ac_id" => :activecampaign,

    # Drip
    "drip_id" => :drip,

    # Marketo
    "mkt_tok" => :marketo,

    # Pardot
    "pi_ad_id" => :pardot,
    "pi_campaign_id" => :pardot,

    # HubSpot
    "_hsenc" => :hubspot_email,
    "_hsmi" => :hubspot_email,
    "hsCtaTracking" => :hubspot_email
  }

  # Private helper functions

  defp is_mobile_email_app?(referrer) when is_binary(referrer) do
    Map.has_key?(@mobile_email_apps, referrer)
  end

  defp is_mobile_email_app?(_), do: false

  defp get_mobile_email_platform(referrer) when is_binary(referrer) do
    Map.get(@mobile_email_apps, referrer, :unknown_email_app)
  end

  defp has_email_utm_medium?(query_params) do
    case parse_query_string(query_params) do
      {:ok, param_map} ->
        utm_medium = Map.get(param_map, "utm_medium", "") |> String.downcase()
        utm_medium in @email_mediums

      {:error, _} ->
        false
    end
  end

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

  defp check_domain(domain) do
    case Map.get(@email_domains, domain) do
      nil -> check_pattern_matches(domain)
      platform -> platform
    end
  end

  defp check_pattern_matches(domain) do
    case Enum.find(@domain_patterns, fn {pattern, _platform} ->
           Regex.match?(pattern, domain)
         end) do
      {_pattern, platform} -> platform
      nil -> :none
    end
  end

  defp has_email_referrer?(referrer) do
    case get_platform_from_referrer(referrer) do
      {:ok, _platform} -> true
      :not_found -> false
    end
  end

  defp has_marketing_email_referrer?(referrer) do
    case get_platform_from_referrer(referrer) do
      {:ok, platform} when platform in @marketing_esp_platforms -> true
      _ -> false
    end
  end

  defp has_transactional_referrer?(referrer) do
    case get_platform_from_referrer(referrer) do
      {:ok, platform} when platform in @transactional_platforms -> true
      _ -> false
    end
  end

  defp has_email_tracking_params?(query_params) do
    case parse_query_string(query_params) do
      {:ok, param_map} ->
        platform_tracking =
          Enum.any?(@email_tracking_params, fn {param_name, _platform} ->
            Map.has_key?(param_map, param_name) and
              Map.get(param_map, param_name) != ""
          end)

        generic_tracking =
          Enum.any?(@generic_email_tracking_params, fn param ->
            Map.has_key?(param_map, param) and Map.get(param_map, param) != ""
          end)

        platform_tracking or generic_tracking

      {:error, _} ->
        false
    end
  end

  defp has_marketing_tracking_params?(param_map) do
    Enum.any?(@email_tracking_params, fn {param_name, platform} ->
      Map.has_key?(param_map, param_name) and
        Map.get(param_map, param_name) != "" and
        platform in @marketing_esp_platforms
    end)
  end

  defp has_campaign_indicators?(param_map) do
    utm_campaign = Map.get(param_map, "utm_campaign", "") |> String.downcase()
    utm_source = Map.get(param_map, "utm_source", "") |> String.downcase()

    Enum.any?(@campaign_indicators, fn indicator ->
      String.contains?(utm_campaign, indicator) or
        String.contains?(utm_source, indicator)
    end)
  end

  defp has_transactional_keywords?(utm_campaign) when is_binary(utm_campaign) do
    campaign_lower = String.downcase(utm_campaign)

    Enum.any?(@transactional_keywords, fn keyword ->
      String.contains?(campaign_lower, keyword)
    end)
  end

  defp get_platform_from_referrer(referrer) do
    case DomainExtractor.extract_base_domain(referrer) do
      {:ok, domain} ->
        case check_domain(domain) do
          :none -> :not_found
          platform -> {:ok, platform}
        end

      {:error, _} ->
        :not_found
    end
  end

  defp get_platform_from_params(param_map) do
    case detect_from_tracking_params(param_map) do
      {:ok, platform} ->
        {:ok, platform}

      :not_found ->
        :not_found
    end
  end

  defp detect_from_tracking_params(param_map) do
    platform_param =
      Enum.find_value(@email_tracking_params, fn {param_name, platform} ->
        if Map.has_key?(param_map, param_name), do: platform, else: nil
      end)

    case platform_param do
      nil -> :not_found
      platform -> {:ok, platform}
    end
  end
end
