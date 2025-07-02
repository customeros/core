defmodule Core.WebTracker.Sessions do
  @moduledoc """
  Context module for managing web sessions.
  Handles all business logic and database operations related to web sessions.
  """

  import Ecto.Query
  alias Plug.Session
  alias Core.Repo
  alias Core.Utils.IdGenerator
  alias Core.WebTracker.Sessions.Session
  alias Core.WebTracker.IPProfiler

  # Session timeout constants (in minutes)
  @page_exit_timeout_minutes 5
  @default_timeout_minutes 30
  @default_limit 100

  # Traffic source detection constants
  @search_engines [
    "google.com",
    "google.",
    "bing.com",
    "bing.",
    "yahoo.com",
    "yahoo.",
    "duckduckgo.com",
    "duckduckgo.",
    "baidu.com",
    "baidu.",
    "yandex.com",
    "yandex."
  ]

  @social_platforms [
    "facebook.com",
    "twitter.com",
    "x.com",
    "linkedin.com",
    "instagram.com",
    "youtube.com",
    "tiktok.com",
    "reddit.com",
    "pinterest.com",
    "snapchat.com"
  ]

  @email_clients [
    "outlook",
    "thunderbird",
    "apple-mail",
    "gmail",
    "yahoo-mail",
    "mail.app",
    "mozilla thunderbird"
  ]

  @email_domains [
    "mail.google.com",
    "outlook.live.com",
    "mail.yahoo.com"
  ]

  @ad_platforms [
    "doubleclick.net",
    "googleadservices.com",
    "googlesyndication.com",
    "facebook.com/tr",
    "ads.facebook.com",
    "bing.com/ads",
    "adnxs.com",
    "amazon-adsystem.com",
    "googletagmanager.com"
  ]

  @affiliate_indicators [
    "affiliate",
    "partner",
    "ref=",
    "aff=",
    "partner_id",
    "affiliate_id"
  ]

  @doc """
  Creates a new web session.
  """
  def create(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs =
      attrs
      |> Map.put(:id, IdGenerator.generate_id_21(Session.id_prefix()))
      |> Map.put(:created_at, now)
      |> Map.put(:updated_at, now)
      |> Map.put(:started_at, now)
      |> Map.put(:last_event_at, now)

    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Sets the company_id for a session by its ID.
  Returns {:ok, session} if updated successfully, {:error, reason} otherwise.
  """
  @spec set_company_id(String.t(), String.t() | nil) ::
          {:ok, Session.t()}
          | {:error, :not_found | :invalid_input | Ecto.Changeset.t()}
  def set_company_id(session_id, company_id) when is_binary(session_id) do
    case get_session_by_id(session_id) do
      {:ok, session} ->
        session
        |> Session.changeset(%{company_id: company_id})
        |> Repo.update()

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  def set_company_id(_, _), do: {:error, :invalid_input}

  @doc """
  Gets an active session for the given tenant, visitor_id and origin combination.
  Returns nil if no active session is found.
  """
  def get_active_session(tenant, visitor_id, origin) do
    result =
      Repo.one(
        from s in Session,
          where:
            s.tenant == ^tenant and
              s.visitor_id == ^visitor_id and
              s.origin == ^origin and
              s.active == true,
          order_by: [desc: s.inserted_at],
          limit: 1
      )

    result
  end

  @doc """
  Gets or creates a session for the given event.
  Returns an existing active session if found, or creates a new one.
  """
  @spec get_or_create_session(Core.WebTracker.Events.Event.t()) ::
          {:ok, Session.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def get_or_create_session(event) when is_map(event) do
    case get_active_session(event.tenant, event.visitor_id, event.origin) do
      nil ->
        # No active session found, create a new one with IP validation
        create_new_session_with_ip_validation(event)

      session ->
        # Active session found, return it
        {:ok, session}
    end
  end

  def get_or_create_session(_), do: {:error, "Invalid event parameter"}

  # Private function to create a new session with IP validation
  defp create_new_session_with_ip_validation(event) do
    case validate_ip_safety(event) do
      {:ok, event, ip_data} ->
        create_session_with_ip_data(event, ip_data)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Validate IP safety using IP intelligence
  defp validate_ip_safety(event) when is_map(event) do
    case IPProfiler.get_ip_data(event.ip) do
      {:ok, ip_data} ->
        if ip_data.is_threat do
          {:error, :ip_is_threat}
        else
          {:ok, event, ip_data}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Create session with IP data
  defp create_session_with_ip_data(
         %{
           tenant: tenant,
           visitor_id: visitor_id,
           origin: origin,
           ip: ip,
           event_type: event_type,
           user_agent: user_agent,
           language: language,
           cookies_enabled: cookies_enabled,
           screen_resolution: screen_resolution,
           hostname: hostname,
           pathname: pathname,
           referrer: referrer
         },
         ip_data
       ) do
    # Derive traffic information from event data
    {traffic_source, traffic_type} = derive_traffic_info(referrer, user_agent, origin)

    session_attrs = %{
      tenant: tenant,
      visitor_id: visitor_id,
      origin: origin,
      ip: ip,
      city: ip_data.city,
      region: ip_data.region,
      country_code: ip_data.country_code,
      is_mobile: ip_data.is_mobile,
      traffic_source: traffic_source,
      traffic_type: traffic_type,
      active: true,
      last_event_type: event_type,
      just_created: true,
      metadata: %{
        user_agent: user_agent,
        language: language,
        cookies_enabled: cookies_enabled,
        screen_resolution: screen_resolution,
        hostname: hostname,
        pathname: pathname,
        referrer: referrer
      }
    }

    case create(session_attrs) do
      {:ok, session} -> {:ok, session}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Derives traffic source and type from referrer, user agent, and origin information.
  Returns a tuple {traffic_source, traffic_type}.
  """
  def derive_traffic_info(referrer, user_agent, origin) do
    host = parse_host(referrer)
    params = parse_query_params(referrer)

    source =
      cond do
        blank_referrer?(referrer, origin) ->
          :direct

        utm = params["utm_source"] ->
          # Validate utm_source against our predefined list
          validate_utm_source(utm)

        host in @search_engines ->
          :search

        host in @social_platforms ->
          :social

        email_traffic?(host, user_agent) ->
          :email

        host in @ad_platforms ->
          :display

        affiliate_traffic?(params, host) ->
          :affiliate

        true ->
          :referral
      end

    medium = if source in [:display, :affiliate] or params["utm_medium"] in ["cpc", "paid"], do: :paid, else: :organic
    {source, medium}
  end

  @doc """
  Validates utm_source against predefined traffic sources.
  Returns a valid traffic source atom or :unknown if not recognized.
  """
  def validate_utm_source(utm_source) when is_binary(utm_source) do
    # Convert to atom and check if it's in our predefined list
    source_atom = String.to_atom(utm_source)

    # Check against our predefined traffic sources
    valid_sources = [:search, :social, :email, :direct, :referral, :display, :video, :affiliate]

    if source_atom in valid_sources do
      source_atom
    else
      # Log unknown utm_source for monitoring
      require Logger
      Logger.warning("Unknown utm_source: #{utm_source}, falling back to :unknown")
      :unknown
    end
  end

  def validate_utm_source(_), do: :unknown

  defp blank_referrer?(referrer, origin) do
    ref = (referrer || "") |> String.trim()
    ref == "" or URI.parse(ref).host in [nil, URI.parse(origin).host]
  end

  defp parse_host(referrer) when is_binary(referrer) do
    referrer
    |> URI.parse()
    |> Map.get(:host, "")
    |> String.trim_leading("www.")
    |> String.downcase()
  end

  defp parse_host(_), do: ""

  defp parse_query_params(referrer) when is_binary(referrer) do
    case URI.parse(referrer).query do
      nil -> %{}
      q -> URI.decode_query(q)
    end
  end

  defp parse_query_params(_), do: %{}

  defp email_traffic?(_host, user_agent) when not is_binary(user_agent), do: false

  defp email_traffic?(host, user_agent) do
    ua = String.downcase(user_agent)
    email_client_pattern = @email_clients |> Enum.join("|") |> then(&~r/\b(#{&1})\b/)
    is_email_client = Regex.match?(email_client_pattern, ua)
    is_email_domain = host in @email_domains
    is_email_client or is_email_domain
  end

  defp affiliate_traffic?(params, host) do
    cond do
      params["utm_medium"] == "affiliate" -> true
      Enum.any?(@affiliate_indicators, &String.contains?(host, &1)) -> true
      true -> false
    end
  end

  @doc """
  Gets a web session record by the session ID
  """
  def get_session_by_id(session_id) do
    case Repo.get(Session, session_id) do
      %Session{} = session -> {:ok, session}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Reterns all closed sessions for a lead
  """
  def get_all_closed_sessions_by_tenant_and_company(tenant, company_id) do
    from(s in Session,
      where:
        s.tenant == ^tenant and s.company_id == ^company_id and
          s.active == false
    )
    |> Repo.all()
    |> then(fn
      [] -> {:error, :closed_sessions_not_found}
      sessions -> {:ok, sessions}
    end)
  end

  @doc """
  Updates the last event information (timestamp and type) for a session.
  """
  def update_last_event(%Session{} = session, event_type) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    session
    |> Session.changeset(%{
      last_event_at: now,
      last_event_type: event_type,
      updated_at: now
    })
    |> Repo.update()
  end

  def update_last_event(session_id, event_type) do
    case get_session_by_id(session_id) do
      {:ok, session} ->
        update_last_event(session, event_type)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns a list of sessions that should be closed based on their last event type and timestamp.

  Conditions for closure:
  - Session must be active
  - For page_exit events: last event older than #{@page_exit_timeout_minutes} minutes
  - For other events: last event older than #{@default_timeout_minutes} minutes

  Results are ordered by last_event_at (oldest first) and limited by the input parameter.
  If limit is 0 or negative, defaults to #{@default_limit}.
  """
  def get_sessions_to_close(limit) when not is_integer(limit),
    do: {:error, "limit must be an integer"}

  def get_sessions_to_close(limit) when limit <= 0,
    do: get_sessions_to_close(@default_limit)

  def get_sessions_to_close(limit) do
    now = DateTime.utc_now()

    page_exit_cutoff =
      DateTime.add(now, -@page_exit_timeout_minutes * 60, :second)

    default_cutoff = DateTime.add(now, -@default_timeout_minutes * 60, :second)
    page_exit_event_str = :page_exit |> Atom.to_string()

    from(s in Session,
      where:
        s.active == true and
          ((s.last_event_type == ^page_exit_event_str and
              s.last_event_at < ^page_exit_cutoff) or
             (s.last_event_type != ^page_exit_event_str and
                s.last_event_at < ^default_cutoff)),
      order_by: [asc: s.last_event_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Closes a web session by setting active to false and ended_at to the last_event_at timestamp.
  Returns {:ok, session} if closed successfully or if already closed.
  """
  def close(%Session{} = session) when is_nil(session.id),
    do: {:error, "Session ID is required"}

  def close(%Session{active: false} = session),
    # Session already closed, return as is
    do: {:ok, session}

  def close(%Session{} = session) do
    session
    |> Session.changeset(%{
      active: false,
      ended_at: session.last_event_at
    })
    |> Repo.update()
    |> tap(fn {:ok, result} -> after_session_closed(result) end)
  end

  defp after_session_closed(%Session{} = session) do
    Core.WebTracker.SessionAnalyzer.start(session.id)
  end
end
