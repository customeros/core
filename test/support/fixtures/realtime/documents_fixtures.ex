defmodule Core.Realtime.DocumentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Core.Realtime.Documents` context.
  """

  @doc """
  Generate a document.
  """
  def document_fixture(attrs \\ %{}) do
    {:ok, %{document: document}} =
      attrs
      |> Enum.into(%{
        name: "Test Document #{System.unique_integer()}",
        body: "Test content #{System.unique_integer()}",
        tenant: "test_tenant",
        user_id: Ecto.UUID.generate(),
        icon: "📄",
        color: "#000000",
        organization_id: Ecto.UUID.generate()
      })
      |> Core.Realtime.Documents.create_document()

    document
  end

  @doc """
  Generate a document write.
  """
  def document_write_fixture(attrs \\ %{}) do
    document = document_fixture()

    {:ok, write} =
      attrs
      |> Enum.into(%{
        docName: document.id,
        value: "Updated content #{System.unique_integer()}",
        version: :v1
      })
      |> Core.Realtime.Documents.DocumentWrite.changeset(%Core.Realtime.Documents.DocumentWrite{})
      |> Core.Repo.insert()

    write
  end
end
