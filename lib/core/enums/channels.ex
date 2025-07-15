defmodule Core.Enums.Channels do
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
