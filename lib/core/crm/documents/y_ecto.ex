defmodule Core.Crm.Documents.YEcto do
  @moduledoc """
  Provides Yjs document synchronization functionality through Ecto.

  This module manages:
  * Yjs document state persistence
  * Update tracking and versioning
  * State vector management
  * Document synchronization
  * Update batching and flushing

  It implements a macro that can be used to add Yjs document
  synchronization capabilities to any Ecto schema. The module
  handles document updates, state vectors, and efficient storage
  of collaborative editing changes, with support for batching
  updates to optimize database operations.
  """

  defmacro __using__(opts) do
    repo = opts[:repo]
    schema = opts[:schema]

    quote do
      import Ecto.Query

      @repo unquote(repo)
      @schema unquote(schema)

      @flush_size 400

      def get_y_doc(doc_name) do
        ydoc = Yex.Doc.new()

        updates = get_updates(doc_name)

        Yex.Doc.transaction(ydoc, fn ->
          Enum.each(updates, fn update ->
            Yex.apply_update(ydoc, update.value)
          end)
        end)

        if length(updates) > @flush_size do
          {:ok, u} = Yex.encode_state_as_update(ydoc)
          {:ok, sv} = Yex.encode_state_vector(ydoc)
          clock = List.last(updates, nil).inserted_at
          flush_document(doc_name, u, sv, clock)
        end

        ydoc
      end

      def insert_update(doc_name, value) do
        @repo.insert(%@schema{
          document_id: doc_name,
          value: value,
          version: :v1
        })
      end

      def get_state_vector(doc_name) do
        query =
          from y in @schema,
            where: y.document_id == ^doc_name and y.version == :v1_sv,
            select: y

        @repo.one(query)
      end

      def get_diff(doc_name, sv) do
        doc = get_y_doc(doc_name)
        Yex.encode_state_as_update(doc, sv)
      end

      def clear_document(doc_name) do
        query =
          from y in @schema,
            where: y.document_id == ^doc_name

        @repo.delete_all(query)
      end

      defp put_state_vector(doc_name, state_vector) do
        case get_state_vector(doc_name) do
          nil -> %@schema{document_id: doc_name, version: :v1_sv}
          state_vector -> state_vector
        end
        |> @schema.changeset(%{value: state_vector})
        |> @repo.insert_or_update()
      end

      defp get_updates(doc_name) do
        query =
          from y in @schema,
            where: y.document_id == ^doc_name and y.version == :v1,
            select: y,
            order_by: y.inserted_at

        @repo.all(query)
      end

      defp flush_document(doc_name, updates, sv, clock) do
        @repo.insert(%@schema{
          document_id: doc_name,
          value: updates,
          version: :v1
        })

        put_state_vector(doc_name, sv)
        clear_updates_to(doc_name, clock)
      end

      defp clear_updates_to(doc_name, to) do
        query =
          from y in @schema,
            where: y.document_id == ^doc_name and y.inserted_at < ^to

        @repo.delete_all(query)
      end
    end
  end
end
