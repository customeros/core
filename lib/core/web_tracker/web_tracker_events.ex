defmodule Core.WebTracker.WebTrackerEvents do
  @moduledoc """
  Context module for managing web tracker events.
  Handles all business logic and database operations related to web tracker events.
  """

  alias Core.Repo
  alias Core.Utils.IdGenerator
  alias Core.WebTracker.Schemas.WebTrackerEvent

  @doc """
  Creates a new web tracker event.
  """
  @spec create(map()) ::
          {:ok, WebTrackerEvent.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs =
      attrs
      |> Map.put(:id, IdGenerator.generate_id_21(WebTrackerEvent.id_prefix()))
      |> Map.put(:created_at, now)

    %WebTrackerEvent{}
    |> WebTrackerEvent.changeset(attrs)
    |> Repo.insert()
  end
end
