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

  alias Core.WebTracker.IPIntelligence
  alias Core.WebTracker.WebSessions
  alias Core.WebTracker.WebTrackerEvents

  @doc """
  Process a new web tracker event.
  Handles session management and IP validation.
  """
  @spec process_new_event(map()) :: {:ok, map()} | {:error, atom(), String.t()}
  def process_new_event(
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
    # Check for existing active session
    case WebSessions.get_active_session(tenant, visitor_id, origin) do
      nil ->
        # No active session, verify IP and create new session
        case IPIntelligence.get_ip_data(ip) do
          {:ok, ip_data} ->
            if ip_data.is_threat do
              {:error, :forbidden, "ip is a threat"}
            else
              # Create new session with IP data
              session_attrs = %{
                tenant: tenant,
                visitor_id: visitor_id,
                origin: origin,
                ip: ip,
                city: ip_data.city,
                region: ip_data.region,
                country_code: ip_data.country_code,
                is_mobile: ip_data.is_mobile,
                last_event_type: event_type
              }

              case WebSessions.create(session_attrs) do
                {:ok, session} ->
                  # Create event with new session
                  create_event(attrs, session)

                  # Get company info from Snitcher after session creation
                  case IPIntelligence.get_company_info(ip) do
                    {:ok, %{domain: domain, company: company}} ->
                      case company do
                        nil ->
                          Logger.warning(
                            "Company not found for ip #{ip}: domain: #{domain}"
                          )

                        company ->
                          Logger.info(
                            "Found company for ip #{ip}: domain: #{domain} company: #{company.name}"
                          )

                          case Core.Company.Service.get_or_create_by_domain(
                                 domain
                               ) do
                            {:ok, company} ->
                              Core.Crm.Leads.get_or_create(tenant, %{
                                ref_id: company.id,
                                type: :company
                              })
                          end

                          # TODO: Create lead by domain
                          # This will be implemented as an async call to another service
                      end

                    {:error, reason} ->
                      Logger.error(
                        "Failed to get company info: #{inspect(reason)}"
                      )
                  end

                  {:ok, %{status: :accepted, session_id: session.id}}

                {:error, _changeset} ->
                  {:error, :internal_server_error, "failed to create session"}
              end
            end

          {:error, reason} ->
            Logger.error("Failed to get IP data: #{inspect(reason)}")
            {:error, :internal_server_error, "failed to process request"}
        end

      session ->
        # Create event with existing session
        create_event(attrs, session)
    end
  end

  def process_new_event(_),
    do: {:error, :bad_request, "invalid or missing parameters"}

  defp create_event(attrs, session) do
    event_attrs = %{
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

    with {:ok, _event} <- WebTrackerEvents.create(event_attrs),
         {:ok, _session} <-
           WebSessions.update_last_event(session, attrs.event_type) do
      {:ok, %{status: :accepted, session_id: session.id}}
    else
      {:error, _changeset} ->
        {:error, :internal_server_error, "failed to create event"}
    end
  end

  @doc """
  Check if the request is from a bot based on user agent.
  """
  @spec check_bot(String.t()) :: :ok | {:error, :bot}
  def check_bot(user_agent) when is_binary(user_agent) and user_agent != "" do
    # Simple bot detection - can be enhanced later
    if String.match?(String.downcase(user_agent), ~r/(bot|crawler|spider)/),
      do: {:error, :bot},
      else: :ok
  end

  def check_bot(_), do: {:error, :bot}

  @doc """
  Check if the referrer is suspicious.
  """
  @spec check_suspicious(String.t()) :: :ok | {:error, :suspicious}
  def check_suspicious(referrer) when is_binary(referrer) and referrer != "" do
    # Simple suspicious URL detection - can be enhanced later
    if String.match?(String.downcase(referrer), ~r/(porn|xxx|gambling|casino)/),
      do: {:error, :suspicious},
      else: :ok
  end

  def check_suspicious(_), do: {:error, :suspicious}
end
