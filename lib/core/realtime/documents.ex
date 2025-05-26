defmodule Core.Realtime.Documents do
  @moduledoc """
  The Documents context.
  """

  import Ecto.Query, warn: false
  alias Core.Repo
  alias Core.Realtime.Documents.Document

  @doc """
  Creates a document.
  """
  def create_document(attrs \\ %{}) do
    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, document} -> {:ok, %{document: document}}
      {:error, changeset} -> {:error, :document, changeset, %{}}
    end
  end

  @doc """
  Updates a document.
  """
  def update_document(%{id: id} = attrs) do
    case get_document(id) do
      {:ok, document} ->
        document
        |> Document.changeset(attrs)
        |> Repo.update()

      {:error, :not_found} = error ->
        error
    end
  end

  @doc """
  Deletes a document.
  """
  def delete_document(id) do
    case get_document(id) do
      {:ok, document} ->
        Repo.delete(document)

      {:error, :not_found} = error ->
        error
    end
  end

  @doc """
  Returns the list of documents for an organization and tenant.
  """
  def list_by_organization(organization_id, tenant) do
    Document
    |> where([d], d.organization_id == ^organization_id and d.tenant == ^tenant)
    |> Repo.all()
  end

  @doc """
  Gets a single document.
  """
  def get_document(id) do
    case Repo.get(Document, id) do
      nil -> {:error, :not_found}
      document -> {:ok, document}
    end
  end
end
