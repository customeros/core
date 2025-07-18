defmodule Core.Enums.Channels do
  @moduledoc """
  Defines the various marketing and communication channels through which users can interact with the system.

  Channels represent different traffic sources and interaction methods, including:
  - Direct visits
  - Organic search and social media
  - Paid advertising channels
  - Email campaigns
  - Workplace tool integrations
  """

  @channel_types [
    :direct,
    :organic_search,
    :organic_social,
    :referral,
    :paid_search,
    :paid_social,
    :email,
    :workplace_tools
  ]

  def channels, do: @channel_types
end
