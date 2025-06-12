defmodule Core.Stats.UserEvent do
  @moduledoc """
  Defines the schema and functions for tracking user events in the system.

  This module handles:
  * User event data structure and validation
  * Event type definitions and validation
  * Changeset creation for user events
  * Tracking of user actions like login, logout, document views, etc.

  Events are stored in the `user_events` table and include:
  * User identification
  * Event type
  * Timestamp of the event
  """

  use Ecto.Schema
  import Ecto.Changeset

  @event_types [:login, :logout, :view_document, :download_document]

  schema "user_events" do
    field(:user_id, :string)
    field(:event_type, :string)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for user event.
  """
  def changeset(user_event, attrs) do
    user_event
    |> cast(attrs, [:user_id, :event_type])
    |> validate_required([:user_id, :event_type])
    |> validate_length(:user_id, min: 1, message: "must be a non-empty string")
    |> validate_inclusion(
      :event_type,
      Enum.map(@event_types, &Atom.to_string/1)
    )
  end

  @doc """
  Returns list of valid event types.
  """
  def event_types, do: @event_types
end
