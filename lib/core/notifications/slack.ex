defmodule Core.Notifications.Slack do
  @moduledoc """
  Handles Slack notifications for various system events.
  Provides both generic Slack message sending and specific notification types.
  """

  require Logger

  @doc """
  Generic function to send a message to Slack.
  Returns :ok on success or {:error, reason} on failure.
  """
  @spec send_message(String.t(), map()) :: :ok | {:error, :slack_api_error | Finch.Error.t()}
  def send_message(webhook_url, message) when is_binary(webhook_url) and is_map(message) do
    case Finch.request(Core.Finch, :post, webhook_url, [{"Content-Type", "application/json"}], Jason.encode!(message)) do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status_code}} ->
        Logger.error("Slack API returned status code #{status_code}")
        {:error, :slack_api_error}

      {:error, %Finch.Error{} = error} ->
        Logger.error("Failed to send Slack message: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Sends a notification about a new tenant registration.
  Includes tenant name, domain, and registration timestamp.
  """
  @spec notify_new_tenant(String.t(), String.t()) :: :ok | {:error, :webhook_not_configured | :slack_api_error | Finch.Error.t()}
  def notify_new_tenant(name, domain) when is_binary(name) and is_binary(domain) do
    webhook_url = Application.get_env(:core, :slack)[:new_tenant_webhook_url]

    unless webhook_url do
      Logger.warning("Slack new tenant webhook URL not configured")
      {:error, :webhook_not_configured}
    else
      message = %{
        blocks: [
          %{
            type: "header",
            text: %{
              type: "plain_text",
              text: "🏢 New Tenant Registration",
              emoji: true
            }
          },
          %{
            type: "section",
            fields: [
              %{
                type: "mrkdwn",
                text: "*Tenant Name:*\n#{name}"
              },
              %{
                type: "mrkdwn",
                text: "*Domain:*\n#{domain}"
              }
            ]
          },
          %{
            type: "context",
            elements: [
              %{
                type: "mrkdwn",
                text: "Registered at: #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")}"
              }
            ]
          }
        ]
      }

      send_message(webhook_url, message)
    end
  end
end
