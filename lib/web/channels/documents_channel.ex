defmodule Web.Channels.DocumentsChannel do
  @moduledoc """
  Phoenix Channel for managing real-time collaborative document editing.

  This channel handles:
  * Real-time document synchronization using Yjs
  * Shared document state management
  * Document persistence and recovery
  * Collaborative editing sessions
  * Document access control (TODO)

  It integrates with Yex.Sync for handling real-time document synchronization
  and provides a WebSocket interface for collaborative editing features.
  The channel manages document lifecycle and ensures consistent state
  across all connected clients.
  """

  use Web, :channel

  require Logger

  alias Yex.Sync.SharedDoc
  alias Core.Stats

  @impl true
  def join("documents:" <> doc_name, payload, socket) do
    # TODO: code for authorization is commented until implemented
    #    if authorized?(payload) do
    case start_shared_doc(doc_name) do
      {:ok, docpid} ->
        Process.monitor(docpid)
        SharedDoc.observe(docpid)

        if user_id = payload["user_id"],
          do: Stats.register_event_start(user_id, :view_document)

        {:ok, socket |> assign(doc_name: doc_name, doc_pid: docpid)}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end

    #    else
    #      {:error, %{reason: "unauthorized"}}
    #    end
  end

  @impl true
  def handle_in("yjs_sync", {:binary, chunk}, socket) do
    SharedDoc.start_sync(socket.assigns.doc_pid, chunk)
    {:noreply, socket}
  end

  def handle_in("yjs", {:binary, chunk}, socket) do
    SharedDoc.send_yjs_message(socket.assigns.doc_pid, chunk)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:yjs, message, _proc}, socket) do
    push(socket, "yjs", {:binary, message})
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:DOWN, _ref, :process, _pid, _reason},
        socket
      ) do
    {:stop, {:error, "remote process crash"}, socket}
  end

  defp start_shared_doc(doc_name) do
    case :global.whereis_name({__MODULE__, doc_name}) do
      :undefined ->
        SharedDoc.start(
          [doc_name: doc_name, persistence: Core.Crm.Documents.EctoPersistence],
          name: {:global, {__MODULE__, doc_name}}
        )

      pid ->
        {:ok, pid}
    end
    |> case do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        Logger.error("""
        Failed to start shareddoc.
        Room: #{inspect(doc_name)}
        Reason: #{inspect(reason)}
        """)

        {:error, %{reason: "failed to start shareddoc"}}
    end
  end

  # TODO: Add authorization logic here as required.
  #  defp authorized?(_payload) do
  #    true
  #  end
end
