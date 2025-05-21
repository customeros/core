defmodule Core.WebTracker.WebSessions do
  @moduledoc """
  Context module for managing web sessions.
  Handles all business logic and database operations related to web sessions.
  """

  import Ecto.Query
  alias Core.Repo
  alias Core.Utils.IdGenerator
  alias Core.WebTracker.Schemas.WebSession

  @doc """
  Creates a new web session.
  """
  @spec create(map()) :: {:ok, WebSession.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    attrs = attrs
      |> Map.put(:id, IdGenerator.generate_id_21(WebSession.id_prefix()))
      |> Map.put(:created_at, now)
      |> Map.put(:updated_at, now)
      |> Map.put(:started_at, now)
      |> Map.put(:last_event_at, now)

    %WebSession{}
    |> WebSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets an active session for the given tenant, visitor_id and origin combination.
  Returns nil if no active session is found.
  """
  @spec get_active_session(String.t(), String.t(), String.t()) :: WebSession.t() | nil
  def get_active_session(tenant, visitor_id, origin) do
    from(s in WebSession,
      where: not is_nil(s.tenant) and s.tenant == ^tenant and
             not is_nil(s.visitor_id) and s.visitor_id == ^visitor_id and
             not is_nil(s.origin) and s.origin == ^origin and
             s.active == true
    )
    |> Repo.one()
  end

  @doc """
  Updates the last_event_at timestamp for a session.
  """
  @spec update_last_event_at(WebSession.t()) :: {:ok, WebSession.t()} | {:error, Ecto.Changeset.t()}
  def update_last_event_at(%WebSession{} = session) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    session
    |> WebSession.changeset(%{last_event_at: now, updated_at: now})
    |> Repo.update()
  end
end
