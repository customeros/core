defmodule Web.Graphql.Schema do
  @moduledoc """
  Defines the root GraphQL schema for the application.

  This module serves as the entry point for all GraphQL operations, defining:
  - Root query types and fields
  - Root mutation types and fields
  - Schema-wide type definitions
  - Integration with Absinthe for GraphQL functionality

  The schema imports and composes types from various modules to build a complete
  GraphQL API, currently supporting document-related operations through the
  DocumentTypes module.
  """

  use Absinthe.Schema

  import_types(Web.Graphql.DocumentTypes)

  query do
    import_fields(:document_queries)
  end

  mutation do
    import_fields(:document_mutations)
  end
end
