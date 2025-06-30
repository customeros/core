defmodule Core.Auth.MagicLinkUsageChecker do
  @moduledoc """
  Job responsible for checking if magic links are used.

  This module:
  * Monitors magic links that are not used within 5 minutes
  """

  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query
  alias Core.Repo
  alias Core.Utils.Tracing
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock
  alias Core.Auth.Users.UserToken

  # Constants
  # 1 minute in milliseconds
  @default_interval 1 * 60 * 1000
  # Duration in minutes after which a lock is considered stuck
  @stuck_lock_duration_minutes 30

  @doc """
  Starts the stage evaluator process.
  """
  def start_link(_opts) do
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || false

    if crons_enabled do
      GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    else
      Logger.info("Magic link usage checker is disabled (crons disabled)")
      :ignore
    end
  end

  # Server Callbacks

  @impl true
  def init(_) do
    CronLocks.register_cron(:cron_magic_link_usage_checker)
    schedule_initial_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_user_tokens, state) do
    OpenTelemetry.Tracer.with_span "magic_link_usage_checker.check_user_tokens" do
      lock_uuid = Ecto.UUID.generate()

      case CronLocks.acquire_lock(:cron_magic_link_usage_checker, lock_uuid) do
        %CronLock{} ->
          case fetch_user_tokens_without_usage() do
            {:ok, user_tokens} ->
              OpenTelemetry.Tracer.set_attributes([
                {"user_tokens.count", length(user_tokens)}
              ])

              Enum.each(user_tokens, fn user_token ->
                process_user_token(user_token)
              end)

            {:error, :not_found} ->
              OpenTelemetry.Tracer.set_attributes([
                {"user_tokens.count", 0}
              ])

              Logger.info("No user tokens found without usage")
          end

          CronLocks.release_lock(:cron_magic_link_usage_checker, lock_uuid)

        nil ->
          # Lock not acquired, try to force release if stuck
          Logger.info(
            "Magic link usage checker lock not acquired, attempting to release any stuck locks"
          )

          case CronLocks.force_release_stuck_lock(
                 :cron_magic_link_usage_checker,
                 @stuck_lock_duration_minutes
               ) do
            :ok ->
              Logger.info(
                "Successfully released stuck lock, will retry acquisition on next run"
              )

            :error ->
              Logger.info("No stuck lock found or could not release it")
          end
      end

      schedule_next_check()
      {:noreply, state}
    end
  end

  # Private Functions
  defp process_user_token(%UserToken{} = user_token) do
    OpenTelemetry.Tracer.with_span "magic_link_usage_checker.process_user_token" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.user_token.id", user_token.id},
        {"param.user_token.sent_to", user_token.sent_to}
      ])

      # Send Slack notification
      case Core.Notifications.Slack.notify_no_login(user_token.sent_to) do
        :ok ->
          Logger.info(
            "Sent no-login notification for user: #{user_token.sent_to}"
          )

          # Mark token as alert sent
          mark_slack_alert_sent(user_token)

        {:error, reason} ->
          mark_slack_alert_sent(user_token)

          Tracing.error(
            reason,
            "Failed to send no-login slack notification for email #{user_token.sent_to}"
          )
      end
    end
  end

  defp mark_slack_alert_sent(%UserToken{} = user_token) do
    user_token
    |> Ecto.Changeset.change(%{alert_sent: true})
    |> Repo.update()
    |> case do
      {:ok, _updated_token} ->
        Logger.info("Marked token #{user_token.id} as alert sent")

      {:error, reason} ->
        Logger.error(
          "Failed to mark token #{user_token.id} as alert sent: #{inspect(reason)}"
        )
    end
  end

  defp schedule_initial_check do
    Process.send_after(self(), :check_user_tokens, @default_interval)
  end

  defp schedule_next_check do
    Process.send_after(self(), :check_user_tokens, @default_interval)
  end

  defp fetch_user_tokens_without_usage() do
    minutes_ago_5 = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

    UserToken
    |> where([t], t.inserted_at < ^minutes_ago_5)
    |> where([t], is_nil(t.used_at))
    |> where([t], t.context == "magic_link")
    |> where([t], t.alert_sent == false)
    |> Repo.all()
    |> then(fn
      [] -> {:error, :not_found}
      tokens -> {:ok, tokens}
    end)
  end
end
