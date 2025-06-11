defmodule Core.Crm.Leads.DailyLeadSummarySender do
  @moduledoc """
  GenServer responsible for sending daily lead summaries to tenants.

  This module:
  * Runs daily at 6am UTC
  * Collects leads created in the last 24 hours that are ICP fit (strong or moderate)
  * Groups leads by tenant
  * Prepares and sends email summaries per tenant
  * Uses cron locking to prevent multiple executions
  * Tracks last execution time to prevent duplicate sends
  """

  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query
  import Phoenix.Component
  import Swoosh.Email, except: [from: 2]

  alias Core.Repo
  alias Core.Crm.Leads.Lead
  alias Core.Crm.Companies
  alias Core.Utils.Tracing
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock
  alias Core.Auth.Users
  alias Core.Mailer
  alias Core.Auth.Tenants
  alias Core.Notifications.Slack

  # Constants
  @cron_name :cron_daily_lead_summary_sender
  # Duration in minutes after which a lock is considered stuck
  @stuck_lock_duration_minutes 30
  # Check every 5 minutes
  @check_interval_ms 5 * 60 * 1000
  # Minimum time between executions (23 hours and 30 minutes in seconds)
  @min_execution_interval_seconds 23 * 3600 + 30 * 60
  # Email sender details
  @from_name "CustomerOS"
  @from_email "notification@app.customeros.ai"
  # Base URL for links
  @base_url "https://preview.customeros.ai"
  # Maximum number of companies to show in the list
  @max_companies_in_list 3
  # Stage order for the breakdown
  @stage_order [
    :target,
    :education,
    :solution,
    :evaluation,
    :ready_to_buy
  ]

  def start_link(opts \\ []) do
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || false

    if crons_enabled do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    else
      Logger.info("Daily lead summary sender is disabled (crons disabled)")
      :ignore
    end
  end

  @impl true
  def init(_opts) do
    CronLocks.register_cron(@cron_name)
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_and_send, state) do
    OpenTelemetry.Tracer.with_span "daily_lead_summary_sender.check_and_send" do
      if should_run_now?() do
        lock_uuid = Ecto.UUID.generate()

        case CronLocks.acquire_lock(@cron_name, lock_uuid) do
          %CronLock{} ->
            # Lock acquired, proceed with sending summaries
            process_daily_summaries()
            # Release the lock after processing
            CronLocks.release_lock(@cron_name, lock_uuid)

          nil ->
            # Lock not acquired, try to force release if stuck
            Logger.info(
              "Daily lead summary sender lock not acquired, attempting to release any stuck locks"
            )

            case CronLocks.force_release_stuck_lock(
                   @cron_name,
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
      end

      schedule_check()
      {:noreply, state}
    end
  end

  # Private Functions

  defp should_run_now? do
    now = DateTime.utc_now()

    # Check if it's between 6:00 and 6:20 AM UTC
    time_window_ok = now.hour == 6 and now.minute <= 20

    # Check if enough time has passed since last execution
    time_since_last_execution_ok =
      case CronLocks.get_last_execution_time(@cron_name) do
        nil ->
          true

        last_execution ->
          seconds_since_last = DateTime.diff(now, last_execution)
          seconds_since_last >= @min_execution_interval_seconds
      end

    if time_window_ok and time_since_last_execution_ok do
      Logger.info(
        "Daily lead summary sender will run - within time window and enough time since last execution"
      )

      true
    else
      Logger.debug(
        "Daily lead summary sender skipped - time window: #{time_window_ok}, time since last: #{time_since_last_execution_ok}"
      )

      false
    end
  end

  defp get_today_6am_utc do
    now = DateTime.utc_now()

    date_str =
      "#{now.year}-#{String.pad_leading("#{now.month}", 2, "0")}-#{String.pad_leading("#{now.day}", 2, "0")}"

    {:ok, today_6am} =
      DateTime.new(Date.from_iso8601!(date_str), ~T[06:00:00], "Etc/UTC")

    today_6am
  end

  defp get_yesterday_6am_utc do
    yesterday = Date.add(Date.utc_today(), -1)
    {:ok, yesterday_6am} = DateTime.new(yesterday, ~T[06:00:00], "Etc/UTC")
    yesterday_6am
  end

  defp schedule_check do
    Process.send_after(self(), :check_and_send, @check_interval_ms)
  end

  def process_daily_summaries do
    OpenTelemetry.Tracer.with_span "daily_lead_summary_sender.process_daily_summaries" do
      # Get leads from the last 24 hours that are ICP fit
      leads = fetch_recent_icp_fit_leads()

      Logger.info("Found #{length(leads)} ICP fit leads in the last 24 hours")

      # Group leads by tenant
      leads_by_tenant = Enum.group_by(leads, & &1.tenant_id)

      # Process each tenant's leads
      Enum.each(leads_by_tenant, fn {tenant_id, tenant_leads} ->
        process_tenant_leads(tenant_id, tenant_leads)
      end)

      # Prepare data for Slack summary
      tenant_leads =
        leads_by_tenant
        |> Enum.map(fn {tenant_id, tenant_leads} ->
          case Tenants.get_tenant_by_id(tenant_id) do
            {:ok, tenant} -> {tenant.name, length(tenant_leads)}
            _ -> {tenant_id, length(tenant_leads)}
          end
        end)
        |> Enum.sort_by(fn {name, _count} -> String.downcase(name) end)

      # Send Slack summary
      send_slack_summary(tenant_leads)
    end
  end

  defp fetch_recent_icp_fit_leads do
    yesterday_6am = get_yesterday_6am_utc()
    today_6am = get_today_6am_utc()

    Lead
    |> where([l], l.icp_fit in [:strong, :moderate])
    |> where(
      [l],
      l.inserted_at >= ^yesterday_6am and l.inserted_at < ^today_6am
    )
    |> Repo.all()
  end

  defp process_tenant_leads(tenant_id, leads) when length(leads) > 0 do
    OpenTelemetry.Tracer.with_span "daily_lead_summary_sender.process_tenant_leads" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.id", tenant_id},
        {"leads.count", length(leads)}
      ])

      # Get all confirmed users for this tenant
      users = Users.get_users_by_tenant(tenant_id)
      user_emails = Enum.map(users, & &1.email)

      if Enum.empty?(user_emails) do
        Logger.info(
          "Skipping daily lead summary for tenant #{tenant_id} - no confirmed users found"
        )
      else
        subject = generate_email_subject(leads)
        {html_body, text_body} = render_email_content(leads)

        # Send email to all users in the tenant
        Enum.each(user_emails, fn email ->
          case deliver_lead_summary(email, subject, html_body, text_body) do
            {:ok, _email} ->
              Logger.info("Successfully sent daily lead summary to #{email}",
                tenant_id: tenant_id,
                leads_count: length(leads)
              )

            {:error, reason} ->
              Tracing.error(
                reason,
                "Failed to send daily lead summary to #{email}",
                tenant_id: tenant_id
              )
          end
        end)
      end
    end
  end

  # Handle empty leads list
  defp process_tenant_leads(tenant_id, []),
    do:
      Logger.info(
        "Skipping daily lead summary for tenant #{tenant_id} - no leads to report"
      )


  defp send_slack_summary(tenant_leads)
       when is_list(tenant_leads)
       and length(tenant_leads) > 0 do
    webhook_url = Application.get_env(:core, :slack)[:daily_lead_summary_webhook_url]

    case webhook_url do
      val when val in [nil, ""] ->
        Logger.warning("Slack daily lead summary webhook URL not configured")
        {:error, :webhook_not_configured}

      _ ->
        # Create the message blocks
        message = %{
          blocks: [
            %{
              type: "header",
              text: %{
                type: "plain_text",
                text: "📊 Daily Lead Summary Report",
                emoji: true
              }
            },
            %{
              type: "section",
              text: %{
                type: "mrkdwn",
                text: format_tenant_table(tenant_leads)
              }
            },
            %{
              type: "context",
              elements: [
                %{
                  type: "mrkdwn",
                  text: "Generated at: #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")}"
                }
              ]
            }
          ]
        }

        case Slack.send_message(webhook_url, message) do
          :ok ->
            Logger.info("Successfully sent Slack daily lead summary report")
            :ok

          {:error, reason} ->
            Logger.error("Failed to send Slack daily lead summary report: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  # Handle empty list case
  defp send_slack_summary([]), do: :ok

  defp format_tenant_table(tenant_rows) do
    # Calculate column widths
    max_name_length = Enum.max_by(tenant_rows, fn {name, _} -> String.length(name) end) |> elem(0) |> String.length()
    max_count_length = Enum.max_by(tenant_rows, fn {_, count} -> to_string(count) |> String.length() end) |> elem(1) |> to_string() |> String.length()

    # Format header
    header = String.pad_trailing("Tenant", max_name_length) <> " | " <> String.pad_leading("Leads", max_count_length)
    separator = String.duplicate("-", max_name_length) <> "-+-" <> String.duplicate("-", max_count_length)

    # Format rows
    rows =
      Enum.map(tenant_rows, fn {name, count} ->
        String.pad_trailing(name, max_name_length) <> " | " <> String.pad_leading(to_string(count), max_count_length)
      end)

    # Combine all parts
    [header, separator | rows] |> Enum.join("\n")
  end

  defp deliver_lead_summary(to, subject, html_body, text_body) do
    email =
      new()
      |> to(to)
      |> Swoosh.Email.from({@from_name, @from_email})
      |> subject(subject)
      |> html_body(html_body)
      |> text_body(text_body)
      |> put_provider_option(:track_opens, false)
      |> put_provider_option(:track_links, "None")
      |> put_provider_option(:message_stream, "daily-lead-summary")

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  defp email_layout(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <style>
          body {
            font-family: system-ui, sans-serif;
            margin: 3em auto;
            overflow-wrap: break-word;
            word-break: break-all;
            max-width: 1024px;
            padding: 0 1em;
            color: #121926;
          }
        </style>
      </head>
      <body>
        {render_slot(@inner_block)}
      </body>
    </html>
    """
  end

  defp format_stage(stage) do
    stage
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp get_company_name(ref_id) do
    case Companies.get_by_id(ref_id) do
      {:ok, company} ->
        if company.name && company.name != "" do
          company.name
        else
          company.primary_domain
        end

      _ ->
        "Unknown Company"
    end
  end

  defp single_lead_content(assigns) do
    company_name = get_company_name(assigns.lead.ref_id)
    formatted_stage = format_stage(assigns.lead.stage)

    assigns =
      Map.merge(assigns, %{
        company_name: company_name,
        formatted_stage: formatted_stage
      })

    ~H"""
    <.email_layout>
      <p>Hey 👋</p>

      <p>
        You’ve got one new lead today: <strong><%= @company_name %></strong>, currently in the
        <strong>{@formatted_stage}</strong>
        stage.
      </p>

      <p>Cheers,<br />The CustomerOS Team</p>
    </.email_layout>
    """
  end

  defp multiple_leads_same_stage_content(assigns) do
    leads_with_company =
      Enum.map(assigns.leads, fn lead ->
        company_name = get_company_name(lead.ref_id)
        formatted_stage = format_stage(lead.stage)
        Map.put(lead, :company_name, company_name)
        |> Map.put(:formatted_stage, formatted_stage)
      end)
      |> Enum.take(@max_companies_in_list)

    assigns =
      Map.merge(assigns, %{
        leads_with_company: leads_with_company,
        formatted_stage:
          format_stage(assigns.leads |> List.first() |> Map.get(:stage)),
        base_url: @base_url
      })

    ~H"""
    <.email_layout>
      <p>Hey 👋</p>

      <p>
        We added {length(@leads)} new leads to your pipeline in the
        <strong>{@formatted_stage}</strong>
        stage in the last 24 hours:
      </p>

      <div style="margin: 0.5em 0;">
        <ul style="list-style-type: none; padding-left: 0; margin: 0;">
          <%= for lead <- @leads_with_company do %>
            <li style="margin: 0;">• {lead.company_name}</li>
          <% end %>
        </ul>
      </div>

      <p>👉 <a href={@base_url}>See all leads</a></p>

      <p>Cheers,<br />The CustomerOS Team</p>
    </.email_layout>
    """
  end

  defp multiple_leads_mixed_stages_content(assigns) do
    # Group leads by stage and count them
    leads_by_stage = Enum.group_by(assigns.leads, & &1.stage)

    stage_counts =
      Map.new(leads_by_stage, fn {stage, leads} -> {stage, length(leads)} end)

    # Get companies for the last stage that has leads
    last_stage_with_leads =
      @stage_order
      |> Enum.reverse()
      |> Enum.find(fn stage -> Map.get(stage_counts, stage, 0) > 0 end)

    companies_for_last_stage =
      case last_stage_with_leads do
        nil ->
          []

        stage ->
          leads_by_stage[stage]
          |> Enum.map(fn lead -> get_company_name(lead.ref_id) end)
          |> Enum.take(@max_companies_in_list)
      end

    assigns =
      Map.merge(assigns, %{
        stage_counts: stage_counts,
        companies_for_last_stage: companies_for_last_stage,
        base_url: @base_url,
        stage_order: @stage_order
      })

    ~H"""
    <.email_layout>
      <p>Hey 👋</p>

      <p>
        We added {length(@leads)} high-fit leads to your pipeline in the last 24 hours.
      </p>

      <div style="margin: 0.5em 0;">
        <%= for stage <- @stage_order do %>
          <% count = Map.get(@stage_counts, stage, 0) %>
          <%= if count > 0 do %><p style="margin: 0; padding-bottom: 4px;"><strong><%= format_stage(stage) %></strong>: {count}</p><% end %>
        <% end %>
      </div>

      <p>A few from today's batch:</p>

      <%= if length(@companies_for_last_stage) > 0 do %>
        <div style="margin: 0.5em 0;">
          <ul style="list-style-type: none; padding-left: 0; margin: 0;">
            <%= for company <- @companies_for_last_stage do %>
              <li style="margin: 0;">• {company}</li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <p>👉 <a href={@base_url}>See all leads</a></p>

      <p>Cheers,<br />The CustomerOS Team</p>
    </.email_layout>
    """
  end

  defp render_email_content(leads) do
    template =
      cond do
        length(leads) == 1 ->
          single_lead_content(%{lead: List.first(leads)})

        length(leads) > 1 ->
          # Check if all leads have the same stage
          stages = Enum.map(leads, & &1.stage) |> Enum.uniq()

          if length(stages) == 1 do
            multiple_leads_same_stage_content(%{leads: leads})
          else
            multiple_leads_mixed_stages_content(%{leads: leads})
          end
      end

    html = heex_to_html(template)
    text = html_to_text(html)

    {html, text}
  end

  defp generate_email_subject(leads) do
    count = length(leads)

    cond do
      count == 1 -> "You have 1 new lead today"
      count > 1 -> "You have #{count} new leads today"
      true -> "No new leads today"
    end
  end

  defp heex_to_html(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp html_to_text(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("body")
    |> Floki.text(sep: "\n\n")
  end
end
