defmodule Core.WebTracker.Events do
  @moduledoc """
  Context module for managing web tracker events.
  Handles all business logic and database operations related to web tracker events.
  """
  import Ecto.Query

  alias Core.Repo
  alias Core.Utils.IdGenerator
  alias Core.WebTracker.Events.Event

  @doc """
  Creates a new web tracker event.
  """
  def create(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs =
      attrs
      |> Map.put(:id, IdGenerator.generate_id_21(Event.id_prefix()))
      |> Map.put(:created_at, now)

    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  def get_visited_pages(session_id) do
    pathnames =
      Event
      |> where([e], e.session_id == ^session_id and not is_nil(e.href))
      |> group_by([e], e.href)
      |> select([e], e.href)
      |> Repo.all()

    case pathnames do
      [] -> {:error, :not_found}
      results -> {:ok, results}
    end
  end
end
