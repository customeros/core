defmodule Core.Notifications.Slack do
  @moduledoc """
  Handles Slack notifications for various system events.
  Provides both generic Slack message sending and specific notification types.
  """

  require Logger

  # Helper function to check if Slack notifications are enabled
  defp slack_enabled? do
    Application.get_env(:core, :slack)[:enabled] != false
  end

  @doc """
  Generic function to send a message to Slack.
  Returns :ok on success or {:error, reason} on failure.
  """
  @spec send_message(String.t(), map()) ::
          :ok | {:error, :slack_api_error | Finch.Error.t()}
  def send_message(webhook_url, message)
      when is_binary(webhook_url) and is_map(message) do
    if slack_enabled?() do
      case Finch.build(
             :post,
             webhook_url,
             [{"Content-Type", "application/json"}],
             Jason.encode!(message)
           )
           |> Finch.request(Core.Finch) do
        {:ok, %{status: 200}} ->
          :ok

        {:ok, %{status: status_code}} ->
          Logger.error("Slack API returned status code #{status_code}")
          {:error, :slack_api_error}

        {:error, %Finch.Error{} = error} ->
          Logger.error("Failed to send Slack message: #{inspect(error)}")
          {:error, error}
      end
    else
      :ok
    end
  end

  @doc """
  Send a notification about a new tenant registration.
  Includes tenant name, domain, and registration timestamp.
  """
  @spec notify_new_tenant(String.t(), String.t()) ::
          :ok
          | {:error,
             :webhook_not_configured | :slack_api_error | Finch.Error.t()}
  def notify_new_tenant(name, domain)
      when is_binary(name) and is_binary(domain) and name != "" and domain != "" do
    case slack_enabled?() do
      false ->
        :ok

      true ->
        webhook_url =
          Application.get_env(:core, :slack)[:new_tenant_webhook_url]

        case webhook_url do
          val when val in [nil, ""] ->
            Logger.warning("Slack new tenant webhook URL not configured")
            {:error, :webhook_not_configured}

          _ ->
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
                      text: "*Tenant:*\n#{name}"
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
                      text:
                        "Registered at: #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")}"
                    }
                  ]
                }
              ]
            }

            send_message(webhook_url, message)
        end
    end
  end

  def notify_new_tenant(_, _), do: {:error, :invalid_input}

  @doc """
  Send a notification about a new user registration.
  Includes user email, tenant name, and registration timestamp.
  """
  @spec notify_new_user(String.t(), String.t()) ::
          :ok
          | {:error,
             :webhook_not_configured | :slack_api_error | Finch.Error.t()}
  def notify_new_user(email, tenant)
      when is_binary(email) and is_binary(tenant) and email != "" and
             tenant != "" do
    case slack_enabled?() do
      false ->
        :ok

      true ->
        webhook_url = Application.get_env(:core, :slack)[:new_user_webhook_url]

        case webhook_url do
          val when val in [nil, ""] ->
            Logger.warning("Slack new user webhook URL not configured")
            {:error, :webhook_not_configured}

          _ ->
            message = %{
              blocks: [
                %{
                  type: "header",
                  text: %{
                    type: "plain_text",
                    text: "👤 New User Registration",
                    emoji: true
                  }
                },
                %{
                  type: "section",
                  fields: [
                    %{
                      type: "mrkdwn",
                      text: "*Email:*\n#{email}"
                    },
                    %{
                      type: "mrkdwn",
                      text: "*Tenant:*\n#{tenant}"
                    }
                  ]
                },
                %{
                  type: "context",
                  elements: [
                    %{
                      type: "mrkdwn",
                      text:
                        "Registered at: #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")}"
                    }
                  ]
                }
              ]
            }

            send_message(webhook_url, message)
        end
    end
  end

  def notify_new_user(_, _), do: {:error, :invalid_input}

  @doc """
  Send a notification about a system crash or error.
  Includes error type, message, module/function context, and timestamp.
  """
  @spec notify_crash(
          String.t(),
          String.t(),
          String.t() | nil,
          String.t() | nil,
          map() | nil
        ) ::
          :ok
          | {:error,
             :webhook_not_configured | :slack_api_error | Finch.Error.t()}
  def notify_crash(
        error_type,
        error_message,
        module_function \\ nil,
        stacktrace \\ nil,
        metadata \\ nil
      )
      when is_binary(error_type) and is_binary(error_message) and
             error_type != "" and error_message != "" do
    case slack_enabled?() do
      false ->
        :ok

      true ->
        webhook_url = Application.get_env(:core, :slack)[:crash_webhook_url]

        case webhook_url do
          val when val in [nil, ""] ->
            Logger.warning("Slack crash webhook URL not configured")
            {:error, :webhook_not_configured}

          _ ->
            build_and_send_crash_messsage(
              webhook_url,
              stacktrace,
              error_type,
              error_message,
              module_function,
              metadata
            )
        end
    end
  end

  @doc """
  Send a notification about an application error (non-crash).
  Includes error type, message, module/function context, and timestamp.
  Uses warning-level styling instead of critical crash styling.
  """
  @spec notify_error(
          String.t(),
          String.t(),
          String.t() | nil,
          String.t() | nil,
          map() | nil
        ) ::
          :ok
          | {:error,
             :webhook_not_configured | :slack_api_error | Finch.Error.t()}
  def notify_error(
        error_type,
        error_message,
        module_function \\ nil,
        stacktrace \\ nil,
        metadata \\ nil
      )
      when is_binary(error_type) and is_binary(error_message) and
             error_type != "" and error_message != "" do
    case slack_enabled?() do
      false ->
        :ok

      true ->
        webhook_url =
          Application.get_env(:core, :slack)[:error_webhook_url] ||
            Application.get_env(:core, :slack)[:crash_webhook_url]

        case webhook_url do
          val when val in [nil, ""] ->
            Logger.warning("Slack error webhook URL not configured")
            {:error, :webhook_not_configured}

          _ ->
            build_and_send_error_message(
              webhook_url,
              stacktrace,
              error_type,
              error_message,
              module_function,
              metadata
            )
        end
    end
  end

  defp build_and_send_crash_messsage(
         webhook_url,
         stacktrace,
         error_type,
         error_message,
         module_function,
         metadata
       ) do
    metadata = if is_list(metadata), do: Map.new(metadata), else: metadata

    system_keys = [
      :module,
      :function,
      :line,
      :file,
      :pid,
      :time,
      :gl,
      :domain,
      :application,
      :mfa,
      :erl_level
    ]

    custom_metadata =
      metadata
      |> Enum.reject(fn {k, _v} -> k in system_keys end)
      |> Enum.reject(fn {k, _v} ->
        k in [:otel_span_id, :otel_trace_flags, :otel_trace_id]
      end)
      |> Enum.into(%{})

    fields = [
      %{
        type: "mrkdwn",
        text: "*Error Type:*\n`#{error_type}`"
      },
      %{
        type: "mrkdwn",
        text:
          "*Message:*\n```#{String.slice(error_message, 0, 200)}#{if String.length(error_message) > 200, do: "...", else: ""}```"
      }
    ]

    # Add module/function if provided
    fields =
      if module_function do
        fields ++
          [
            %{
              type: "mrkdwn",
              text: "*Location:*\n`#{module_function}`"
            }
          ]
      else
        fields
      end

    # Add metadata if present
    fields =
      if custom_metadata && map_size(custom_metadata) > 0 do
        metadata_lines =
          custom_metadata
          |> Enum.map(fn {k, v} -> "*#{k}:* #{v}" end)
          |> Enum.join("\n")

        fields ++
          [
            %{
              type: "mrkdwn",
              text: "*Metadata:*\n" <> metadata_lines
            }
          ]
      else
        fields
      end

    # Build the blocks
    blocks = [
      %{
        type: "header",
        text: %{
          type: "plain_text",
          text: "🚨 System Crash Detected",
          emoji: true
        }
      },
      %{
        type: "section",
        fields: fields
      },
      %{
        type: "context",
        elements: [
          %{
            type: "mrkdwn",
            text:
              "Occurred at: #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")}"
          }
        ]
      }
    ]

    # Add stacktrace section if provided
    blocks =
      if stacktrace && stacktrace != "" do
        stacktrace_preview = String.slice(stacktrace, 0, 1000)

        stacktrace_text =
          if String.length(stacktrace) > 1000,
            do: stacktrace_preview <> "...",
            else: stacktrace_preview

        blocks ++
          [
            %{
              type: "section",
              text: %{
                type: "mrkdwn",
                text: "*Stacktrace:*\n```#{stacktrace_text}```"
              }
            }
          ]
      else
        blocks
      end

    message = %{blocks: blocks}

    try do
      case send_message(webhook_url, message) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to send crash notification: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e in Jason.EncodeError ->
        Logger.error("Failed to encode crash notification: #{inspect(e)}")
        {:error, :encoding_error}

      e ->
        Logger.error(
          "Unexpected error sending crash notification: #{inspect(e)}"
        )

        {:error, :unexpected_error}
    end
  end

  defp build_and_send_error_message(
         webhook_url,
         stacktrace,
         error_type,
         error_message,
         module_function,
         metadata
       ) do
    metadata = if is_list(metadata), do: Map.new(metadata), else: metadata

    system_keys = [
      :module,
      :function,
      :line,
      :file,
      :pid,
      :time,
      :gl,
      :domain,
      :application,
      :mfa,
      :erl_level
    ]

    custom_metadata =
      metadata
      |> Enum.reject(fn {k, _v} -> k in system_keys end)
      |> Enum.reject(fn {k, _v} ->
        k in [:otel_span_id, :otel_trace_flags, :otel_trace_id]
      end)
      |> Enum.into(%{})

    fields = [
      %{
        type: "mrkdwn",
        text: "*Error Type:*\n`#{error_type}`"
      },
      %{
        type: "mrkdwn",
        text:
          "*Message:*\n```#{String.slice(error_message, 0, 200)}#{if String.length(error_message) > 200, do: "...", else: ""}```"
      }
    ]

    # Add module/function if provided
    fields =
      if module_function do
        fields ++
          [
            %{
              type: "mrkdwn",
              text: "*Location:*\n`#{module_function}`"
            }
          ]
      else
        fields
      end

    # Add metadata if present
    fields =
      if custom_metadata && map_size(custom_metadata) > 0 do
        metadata_lines =
          custom_metadata
          |> Enum.map(fn {k, v} -> "*#{k}:* #{v}" end)
          |> Enum.join("\n")

        fields ++
          [
            %{
              type: "mrkdwn",
              text: "*Metadata:*\n" <> metadata_lines
            }
          ]
      else
        fields
      end

    # Build the blocks with warning styling
    blocks = [
      %{
        type: "header",
        text: %{
          type: "plain_text",
          text: "⚠️ Application Error",
          emoji: true
        }
      },
      %{
        type: "section",
        fields: fields
      },
      %{
        type: "context",
        elements: [
          %{
            type: "mrkdwn",
            text:
              "Occurred at: #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")}"
          }
        ]
      }
    ]

    # Add stacktrace section if provided
    blocks =
      if stacktrace && stacktrace != "" do
        stacktrace_preview = String.slice(stacktrace, 0, 800)

        stacktrace_text =
          if String.length(stacktrace) > 800,
            do: stacktrace_preview <> "...",
            else: stacktrace_preview

        blocks ++
          [
            %{
              type: "section",
              text: %{
                type: "mrkdwn",
                text: "*Stacktrace:*\n```#{stacktrace_text}```"
              }
            }
          ]
      else
        blocks
      end

    message = %{blocks: blocks}

    try do
      case send_message(webhook_url, message) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to send error notification: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e in Jason.EncodeError ->
        Logger.error("Failed to encode error notification: #{inspect(e)}")
        {:error, :encoding_error}

      e ->
        Logger.error(
          "Unexpected error sending error notification: #{inspect(e)}"
        )

        {:error, :unexpected_error}
    end
  end
end
