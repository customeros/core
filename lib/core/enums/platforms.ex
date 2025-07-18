defmodule Core.Enums.Platforms do
  @moduledoc """
  Defines a comprehensive list of digital platforms and services.

  This enum includes various types of platforms such as:
  - Search engines
  - Social media platforms
  - Productivity tools
  - Communication platforms
  - AI services
  - Cloud storage solutions
  - Business software

  Used for platform identification and integration purposes.
  """

  @platforms [
    :airtable,
    :asana,
    :baidu,
    :basecamp,
    :bing,
    :box,
    :brave,
    :campaign_monitor,
    :chatgpt,
    :claude,
    :clickup,
    :constant_contact,
    :deepseek,
    :discord,
    :drift,
    :dropbox,
    :duckduckgo,
    :ecosia,
    :facebook,
    :freshworks,
    :gemini,
    :github,
    :google,
    :google_drive,
    :google_meet,
    :google_workspace,
    :gotomeeting,
    :hubspot,
    :instagram,
    :intercom,
    :jira,
    :klaviyo,
    :linkedin,
    :mailchimp,
    :marketo,
    :meta_workplace,
    :metager,
    :microsoft_office,
    :microsoft_onedrive,
    :microsoft_sharepoint,
    :monday,
    :mojeek,
    :notion,
    :pinterest,
    :pipedrive,
    :qwant,
    :reddit,
    :salesforce,
    :searx,
    :seznam,
    :slack,
    :snapchat,
    :stackoverflow,
    :startpage,
    :swisscows,
    :teams,
    :telegram,
    :tiktok,
    :trello,
    :webex,
    :whatsapp,
    :x,
    :yahoo,
    :yammer,
    :yandex,
    :youtube,
    :zendesk,
    :zoho,
    :zoom
  ]

  def platforms, do: @platforms
end
