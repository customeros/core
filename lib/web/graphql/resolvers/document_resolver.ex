defmodule Web.Graphql.Resolvers.DocumentResolver do
  @moduledoc """
  GraphQL resolvers for document-related operations.

  This module provides the GraphQL resolvers that handle document
  operations through the GraphQL API. It includes resolvers for:
  * Listing documents by organization
  * Retrieving individual documents
  * Creating new documents
  * Updating existing documents
  * Deleting documents

  Each resolver integrates with the core Documents context to
  perform the actual database operations while providing a
  GraphQL-friendly interface.
  """

  alias Core.Crm.Documents

  def list_documents(_parent, %{organization_id: id}, %{
        context: ctx
      }) do
    {:ok, Documents.list_by_ref(id, ctx.tenant)}
  end

  def get_document(_parent, %{id: id}, _ctx) do
    Documents.get_document(id)
  end

  def create_document(
        _parent,
        %{input: input},
        _ctx
      ) do
    {:ok, %{document: document}} = Documents.create_document(input)
    {:ok, document}
  end

  def update_document(_parent, args, _ctx) do
    Documents.update_document(args.input)
  end

  def delete_document(_parent, %{id: id}, _ctx) do
    Documents.delete_document(id)
  end
end
