defmodule Core.WebTracker do
  @moduledoc """
  The WebTracker context.
  This module will handle:
  - Web tracker configuration validation
  - Request validation (user agent, referrer)
  - Event processing
  - Session management
  - Event storage
  """
  require Logger
  require OpenTelemetry.Tracer

  alias Core.WebTracker.Sessions
  alias Core.WebTracker.Events
  alias Core.Crm.Companies
  alias Core.Utils.Tracing

  @doc """
  Process a new web tracker event.
  Handles session management and IP validation.
  """
  @spec process_new_event(map()) :: {:ok, map()} | {:error, atom(), String.t()}
  def process_new_event(event_params) when is_map(event_params) do
    OpenTelemetry.Tracer.with_span "web_tracker.process_event" do
      OpenTelemetry.Tracer.set_attributes([
        {"event.params", inspect(event_params)}
      ])

      event_params
      |> validate_event_params()
      |> get_or_create_session()
      |> create_event()
      |> enrich_with_company_data()
      |> format_response()
    end
  end

  def process_new_event(_),
    do: {:error, :bad_request, "invalid or missing parameters"}

  ## Pipeline Steps ##

  defp validate_event_params(attrs) do
    OpenTelemetry.Tracer.with_span "web_tracker.validate_event_params" do
      case validate_event_params_impl(attrs) do
        {:ok, ^attrs} = result ->
          Tracing.ok()
          result

        {:error, :bad_request, reason} = result ->
          Tracing.error(reason, "Failed to validate event params")
          result
      end
    end
  end

  defp validate_event_params_impl(attrs) do
    with :ok <- validate_required_strings(attrs),
         :ok <- validate_boolean_fields(attrs) do
      {:ok, attrs}
    else
      :error -> {:error, :bad_request, "invalid or missing parameters"}
    end
  end

  defp validate_required_strings(attrs) do
    required_fields = [
      :tenant,
      :visitor_id,
      :origin,
      :ip,
      :event_type,
      :href,
      :hostname,
      :pathname,
      :user_agent,
      :language
    ]

    if Enum.all?(required_fields, &valid_string_field?(attrs, &1)) do
      :ok
    else
      :error
    end
  end

  defp valid_string_field?(attrs, field) do
    case Map.get(attrs, field) do
      value when is_binary(value) and value != "" -> true
      _ -> false
    end
  end

  defp validate_boolean_fields(attrs) do
    if Map.get(attrs, :cookies_enabled) in [true, false] do
      :ok
    else
      :error
    end
  end

  defp get_or_create_session({:error, _, _} = error), do: error

  defp get_or_create_session({:ok, attrs}) do
    OpenTelemetry.Tracer.with_span "web_tracker.get_or_create_session" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant", attrs.tenant},
        {"visitor.id", attrs.visitor_id},
        {"origin", attrs.origin}
      ])

      case Sessions.get_active_session(
             attrs.tenant,
             attrs.visitor_id,
             attrs.origin
           ) do
        nil ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.session.status", "new"}
          ])

          create_new_session(attrs)

        session ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.session.status", "existing"}
          ])

          {:ok, attrs, session}
      end
    end
  end

  defp create_new_session(attrs) do
    OpenTelemetry.Tracer.with_span "web_tracker.create_new_session" do
      attrs
      |> validate_ip_safety()
      |> create_session_with_ip_data()
    end
  end

  defp validate_ip_safety(attrs) do
    OpenTelemetry.Tracer.with_span "web_tracker.validate_ip_safety" do
      OpenTelemetry.Tracer.set_attributes([{"ip", attrs.ip}])

      ip_intelligence_mod = get_ip_intelligence_module()

      case ip_intelligence_mod.get_ip_data(attrs.ip) do
        {:ok, ip_data} ->
          if ip_data.is_threat do
            Tracing.error("ip_is_threat")
            {:error, :forbidden, "ip is a threat"}
          else
            Tracing.ok()
            {:ok, attrs, ip_data}
          end

        {:error, reason} ->
          Tracing.error(reason, "Failed to get IP data")
          {:error, :internal_server_error, "failed to process request"}
      end
    end
  end

  defp create_session_with_ip_data({:error, _, _} = error), do: error

  defp create_session_with_ip_data({:ok, attrs, ip_data}) do
    OpenTelemetry.Tracer.with_span "web_tracker.create_session_with_ip_data" do
      session_attrs = %{
        tenant: attrs.tenant,
        visitor_id: attrs.visitor_id,
        origin: attrs.origin,
        ip: attrs.ip,
        city: ip_data.city,
        region: ip_data.region,
        country_code: ip_data.country_code,
        is_mobile: ip_data.is_mobile,
        last_event_type: attrs.event_type,
        just_created: true
      }

      case Sessions.create(session_attrs) do
        {:ok, session} ->
          Tracing.ok()
          {:ok, attrs, session}

        {:error, _changeset} ->
          Tracing.error("session_creation_failed")
          {:error, :internal_server_error, "failed to create session"}
      end
    end
  end

  defp create_event({:error, _, _} = error), do: error

  defp create_event({:ok, attrs, session}) do
    OpenTelemetry.Tracer.with_span "web_tracker.create_event" do
      event_attrs = build_event_attrs(attrs, session)

      with {:ok, _event} <- Events.create(event_attrs),
           {:ok, _session} <-
             Sessions.update_last_event(session, attrs.event_type) do
        Tracing.ok()
        {:ok, attrs, session, :event_created}
      else
        {:error, _changeset} ->
          Tracing.error("event_creation_failed")
          {:error, :internal_server_error, "failed to create event"}
      end
    end
  end

  defp enrich_with_company_data({:error, _, _} = error), do: error

  defp enrich_with_company_data({:ok, attrs, session, :event_created}) do
    OpenTelemetry.Tracer.with_span "web_tracker.enrich_with_company_data" do
      if session.just_created do
        OpenTelemetry.Tracer.set_attributes([
          {"enrichment.type", "new_session"}
        ])

        fetch_and_process_company_data(attrs.ip, attrs.tenant, session.id)
      else
        OpenTelemetry.Tracer.set_attributes([
          {"enrichment.type", "existing_session"}
        ])
      end

      Tracing.ok()
      {:ok, session}
    end
  end

  defp format_response({:error, _, _} = error), do: error

  defp format_response({:ok, session}) do
    {:ok, %{status: :accepted, session_id: session.id}}
  end

  ## Helper Functions ##

  defp build_event_attrs(attrs, session) do
    %{
      tenant: attrs.tenant,
      session_id: session.id,
      visitor_id: attrs.visitor_id,
      ip: attrs.ip,
      event_type: attrs.event_type,
      event_data: attrs.event_data,
      href: attrs.href,
      origin: attrs.origin,
      search: attrs.search,
      hostname: attrs.hostname,
      pathname: attrs.pathname,
      referrer: attrs.referrer,
      user_agent: attrs.user_agent,
      language: attrs.language,
      cookies_enabled: attrs.cookies_enabled,
      screen_resolution: attrs.screen_resolution,
      timestamp: attrs.timestamp
    }
  end

  defp fetch_and_process_company_data(ip, tenant, session_id) do
    OpenTelemetry.Tracer.with_span "web_tracker.fetch_and_process_company_data" do
      OpenTelemetry.Tracer.set_attributes([
        {"ip", ip},
        {"tenant", tenant},
        {"session.id", session_id}
      ])

      span_ctx = OpenTelemetry.Ctx.get_current()

      Task.start(fn ->
        OpenTelemetry.Ctx.attach(span_ctx)

        ip_intelligence_mod = get_ip_intelligence_module()

        case ip_intelligence_mod.get_company_info(ip) do
          {:ok, %{domain: domain, company: company}} ->
            process_company_data(domain, company, tenant, session_id)

          {:error, reason} ->
            Tracing.error(reason, "Failed to get company info",
              session_id: session_id
            )
        end
      end)
    end
  end

  defp process_company_data(domain, nil, _tenant, _session_id) do
    Logger.warning("Company not found for domain", company_domain: domain)
  end

  defp process_company_data(
         domain,
         _company_ip_intelligence,
         tenant,
         session_id
       ) do
    OpenTelemetry.Tracer.with_span "web_tracker.process_company_data" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.domain", domain},
        {"tenant", tenant},
        {"session.id", session_id}
      ])

      Logger.info("Found company for domain #{domain}")

      case Companies.get_or_create_by_domain(domain) do
        {:ok, db_company} ->
          # Try to update session with company ID, but continue even if it fails
          _ =
            case Core.WebTracker.Sessions.set_company_id(
                   session_id,
                   db_company.id
                 ) do
              {:ok, _session} ->
                Logger.info(
                  "Updated session #{session_id} with company ID #{db_company.id}"
                )

                :ok

              {:error, reason} ->
                Logger.warning(
                  "Failed to update session with company ID",
                  reason: reason
                )

                :ok
            end

          case Core.Crm.Leads.get_or_create(tenant, %{
                 ref_id: db_company.id,
                 type: :company
               }) do
            {:ok, _lead} ->
              :ok

            {:error, :not_found} ->
              Tracing.error(:not_found)
              {:error, :not_found}

            {:error, :domain_matches_tenant} ->
              OpenTelemetry.Tracer.set_attributes([
                {"result.lead_creation_result", :domain_matches_tenant}
              ])

              {:error, :domain_matches_tenant}
          end

        {:error, :no_primary_domain} ->
          Tracing.warning(
            :no_primary_domain,
            "No primary domain found for #{domain}"
          )

        {:error, reason} ->
          Tracing.error(reason, "Company not created from webTracker",
            company_domain: domain
          )
      end
    end
  end

  defp get_ip_intelligence_module do
    Application.get_env(
      :core,
      Core.WebTracker.IPProfiler,
      Core.WebTracker.IPProfiler
    )
  end

  ## Validation Functions ##

  @doc """
  Check if the request is from a bot based on user agent.
  """
  @spec check_bot(String.t()) :: :ok | {:error, :bot}
  def check_bot(user_agent) when is_binary(user_agent) and user_agent != "" do
    if bot_user_agent?(user_agent), do: {:error, :bot}, else: :ok
  end

  def check_bot(_), do: {:error, :bot}

  @doc """
  Check if the referrer is suspicious.
  """
  @spec check_suspicious(String.t()) :: :ok | {:error, :suspicious}
  def check_suspicious(referrer) when is_binary(referrer) and referrer != "" do
    if suspicious_referrer?(referrer), do: {:error, :suspicious}, else: :ok
  end

  def check_suspicious(_), do: {:error, :suspicious}

  ## Private Validation Helpers ##

  defp bot_user_agent?(user_agent) do
    String.match?(String.downcase(user_agent), ~r/(bot|crawler|spider)/)
  end

  defp suspicious_referrer?(referrer) do
    String.match?(String.downcase(referrer), ~r/(porn|xxx|gambling|casino)/)
  end
end
