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

  # Session timeout constants (in minutes)
  @page_exit_timeout_minutes 5
  @default_timeout_minutes 30
  @default_limit 100

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
  Gets a web session record by the session ID
  """
  def get_session_by_id(session_id) do
    case Repo.get(Session, session_id) do
      %Session{} = session -> {:ok, session}
      nil -> {:error, :not_found}
    end
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
  end
end
