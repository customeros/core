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
  alias Core.WebTracker.WebSession

  @doc """
  Process a new web tracker event.
  Handles session management and IP validation.
  """
  @spec process_new_event(map()) :: {:ok, map()} | {:error, atom(), String.t()}
  def process_new_event(%{tenant: tenant, visitor_id: visitor_id, origin: origin, ip: ip}) do
    # Check for existing active session
    case WebSession.get_active_session(tenant, visitor_id, origin) do
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
                is_mobile: ip_data.is_mobile
              }

              case WebSession.create(session_attrs) do
                {:ok, session} -> {:ok, %{status: :created, session_id: session.id}}
                {:error, _changeset} -> {:error, :internal_server_error, "failed to create session"}
              end
            end

          {:error, reason} ->
            Logger.error("Failed to get IP data: #{inspect(reason)}")
            {:error, :internal_server_error, "failed to process request"}
        end

      session ->
        # TODO: Handle existing session case
        {:ok, %{status: :accepted, session_id: session.id}}
    end
  end

  def process_new_event(_), do: {:error, :bad_request, "missing required parameters"}

  @doc """
  Check if the request is from a bot based on user agent.
  """
  @spec check_bot(String.t()) :: :ok | {:error, :bot}
  def check_bot(user_agent) do
    # Simple bot detection - can be enhanced later
    if String.match?(String.downcase(user_agent), ~r/(bot|crawler|spider)/),
      do: {:error, :bot},
      else: :ok
  end

  @doc """
  Check if the referrer is suspicious.
  """
  @spec check_suspicious(String.t()) :: :ok | {:error, :suspicious}
  def check_suspicious(referrer) do
    # Simple suspicious URL detection - can be enhanced later
    if String.match?(String.downcase(referrer), ~r/(porn|xxx|gambling|casino)/),
      do: {:error, :suspicious},
      else: :ok
  end
end
