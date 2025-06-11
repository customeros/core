defmodule Core.Stats do
  @moduledoc """
  Provides functionality for tracking and managing user events.
  """

  alias Core.Repo
  alias Core.Stats.UserEvent
  alias Core.Utils.Tracing

  @doc """
  Registers a new user event asynchronously.

  ## Parameters
    - user_id: String representing the user identifier
    - event_type: Atom representing the type of event (:login, :logout, :view_document, :download_document)

  ## Returns
    - `:ok` immediately, as the operation is performed asynchronously

  ## Examples
      iex> Core.Stats.register_event_start("user123", :login)
      :ok
  """
  @spec register_event_start(String.t(), atom()) :: :ok
  def register_event_start(user_id, event_type) do
    Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
      %UserEvent{}
      |> UserEvent.changeset(%{
        user_id: user_id,
        event_type: Atom.to_string(event_type)
      })
      |> Repo.insert()
      |> case do
        {:ok, _event} -> :ok
        {:error, changeset} ->
          Tracing.error(changeset, "Failed to register user event",
            user_id: user_id,
            event_type: event_type
          )
          :error
      end
    end)

    :ok
  end
end
