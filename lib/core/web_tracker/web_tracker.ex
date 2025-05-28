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

  alias Core.WebTracker.WebSessions
  alias Core.WebTracker.WebTrackerEvents
  alias Core.Crm.Companies

  @doc """
  Process a new web tracker event.
  Handles session management and IP validation.
  """
  @spec process_new_event(map()) :: {:ok, map()} | {:error, atom(), String.t()}
  def process_new_event(attrs) when is_map(attrs) do
    OpenTelemetry.Tracer.with_span "web_tracker.process_event" do
      OpenTelemetry.Tracer.set_attributes([
        {"event.type", attrs.event_type},
        {"tenant", attrs.tenant},
        {"visitor.id", attrs.visitor_id}
      ])

      attrs
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
          OpenTelemetry.Tracer.set_status(:ok)
          result
        {:error, :bad_request, reason} = result ->
          OpenTelemetry.Tracer.set_status(:error, reason)
          result
      end
    end
  end

  defp validate_event_params_impl(
         %{
           tenant: tenant,
           visitor_id: visitor_id,
           origin: origin,
           ip: ip,
           event_type: event_type,
           event_data: _event_data,
           href: href,
           search: _search,
           hostname: hostname,
           pathname: pathname,
           referrer: referrer,
           user_agent: user_agent,
           language: language,
           cookies_enabled: cookies_enabled,
           screen_resolution: _screen_resolution,
           timestamp: _timestamp
         } = attrs
       )
       when is_binary(tenant) and
              is_binary(visitor_id) and
              is_binary(origin) and
              is_binary(ip) and
              is_binary(event_type) and
              is_binary(href) and
              is_binary(hostname) and
              is_binary(pathname) and
              is_binary(user_agent) and
              is_binary(language) and
              is_binary(referrer) and
              is_boolean(cookies_enabled) do
    {:ok, attrs}
  end

  defp validate_event_params_impl(_) do
    {:error, :bad_request, "invalid or missing parameters"}
  end

  defp get_or_create_session({:error, _, _} = error), do: error

  defp get_or_create_session({:ok, attrs}) do
    OpenTelemetry.Tracer.with_span "web_tracker.get_or_create_session" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant", attrs.tenant},
        {"visitor.id", attrs.visitor_id},
        {"origin", attrs.origin}
      ])

      case WebSessions.get_active_session(
             attrs.tenant,
             attrs.visitor_id,
             attrs.origin
           ) do
        nil ->
          OpenTelemetry.Tracer.set_attributes([{"session.status", "new"}])
          create_new_session(attrs)
        session ->
          OpenTelemetry.Tracer.set_attributes([{"session.status", "existing"}])
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
            OpenTelemetry.Tracer.set_status(:error, "ip_is_threat")
            {:error, :forbidden, "ip is a threat"}
          else
            OpenTelemetry.Tracer.set_status(:ok)
            {:ok, attrs, ip_data}
          end

        {:error, reason} ->
          Logger.error("Failed to get IP data: #{inspect(reason)}")
          OpenTelemetry.Tracer.set_status(:error, "ip_data_fetch_failed")
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
        last_event_type: attrs.event_type
      }

      case WebSessions.create(session_attrs) do
        {:ok, session} ->
          OpenTelemetry.Tracer.set_status(:ok)
          {:ok, attrs, session}

        {:error, _changeset} ->
          OpenTelemetry.Tracer.set_status(:error, "session_creation_failed")
          {:error, :internal_server_error, "failed to create session"}
      end
    end
  end

  defp create_event({:error, _, _} = error), do: error

  defp create_event({:ok, attrs, session}) do
    OpenTelemetry.Tracer.with_span "web_tracker.create_event" do
      event_attrs = build_event_attrs(attrs, session)

      with {:ok, _event} <- WebTrackerEvents.create(event_attrs),
           {:ok, _session} <-
             WebSessions.update_last_event(session, attrs.event_type) do
        OpenTelemetry.Tracer.set_status(:ok)
        {:ok, attrs, session, :event_created}
      else
        {:error, _changeset} ->
          OpenTelemetry.Tracer.set_status(:error, "event_creation_failed")
          {:error, :internal_server_error, "failed to create event"}
      end
    end
  end

  defp enrich_with_company_data({:error, _, _} = error), do: error

  defp enrich_with_company_data({:ok, attrs, session, :event_created}) do
    OpenTelemetry.Tracer.with_span "web_tracker.enrich_with_company_data" do
      # Only enrich for new sessions (not existing ones)
      if session.inserted_at == session.updated_at do
        OpenTelemetry.Tracer.set_attributes([{"enrichment.type", "new_session"}])
        fetch_and_process_company_data(attrs.ip, attrs.tenant)
      else
        OpenTelemetry.Tracer.set_attributes([{"enrichment.type", "existing_session"}])
      end

      OpenTelemetry.Tracer.set_status(:ok)
      {:ok, session}
    end
  end

  defp format_response({:error, _, _} = error), do: error

  defp format_response({:ok, session}) do
    OpenTelemetry.Tracer.with_span "web_tracker.format_response" do
      OpenTelemetry.Tracer.set_status(:ok)
      {:ok, %{status: :accepted, session_id: session.id}}
    end
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

  defp fetch_and_process_company_data(ip, tenant) do
    Task.start(fn ->
      ip_intelligence_mod = get_ip_intelligence_module()

      case ip_intelligence_mod.get_company_info(ip) do
        {:ok, %{domain: domain, company: company}} ->
          process_company_info(domain, company, tenant)

        {:error, reason} ->
          Logger.error("Failed to get company info: #{inspect(reason)}")
      end
    end)
  end

  defp process_company_info(domain, nil, _tenant) do
    Logger.warning("Company not found for domain: #{domain}")
  end

  defp process_company_info(domain, company, tenant) do
    Logger.info("Found company for domain #{domain}: #{company.name}")

    with {:ok, db_company} <- Companies.get_or_create_by_domain(domain),
         {:ok, lead} <-
           Core.Crm.Leads.get_or_create(tenant, %{
             ref_id: db_company.id,
             type: :company
           }) do
      case Core.Auth.Tenants.get_tenant_by_name(tenant) do
        {:ok, tenant} ->
          Core.Researcher.Orchestrator.evaluate_icp_fit(
            tenant.id,
            lead.id,
            domain
          )

        {:error, reason} ->
          {:error, reason}
      end

      {:ok}
    else
      {:error, reason} ->
        Logger.error(
          "Failed to create lead for company #{company.name}: #{inspect(reason)}"
        )
    end
  end

  defp get_ip_intelligence_module do
    Application.get_env(
      :core,
      Core.WebTracker.IPIntelligence,
      Core.WebTracker.IPIntelligence
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
