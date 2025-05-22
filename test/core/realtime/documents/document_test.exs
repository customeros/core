defmodule Core.Realtime.Documents.DocumentTest do
  use Core.DataCase

  alias Core.Realtime.Documents.Document

  describe "document" do
    import Core.Realtime.DocumentsFixtures

    test "create_document/1 with valid data creates a document" do
      valid_attrs = %{
        name: "Test Document",
        body: "This is a test document",
        tenant: "test_tenant",
        user_id: Ecto.UUID.generate(),
        icon: "📄",
        color: "#000000",
        organization_id: Ecto.UUID.generate()
      }

      assert {:ok, %{document: document}} = Core.Realtime.Documents.create_document(valid_attrs)
      assert document.name == "Test Document"
      assert document.body == "This is a test document"
      assert document.tenant == "test_tenant"
      assert document.icon == "📄"
      assert document.color == "#000000"
    end

    test "create_document/1 with invalid data returns error changeset" do
      assert {:error, :document, %Ecto.Changeset{}, _} = Core.Realtime.Documents.create_document(%{})
    end

    test "update_document/2 with valid data updates the document" do
      document = document_fixture()
      update_attrs = %{
        id: document.id,
        name: "Updated Title",
        icon: "📝",
        color: "#FFFFFF"
      }

      assert {:ok, %Document{} = updated_document} = Core.Realtime.Documents.update_document(update_attrs)
      assert updated_document.name == "Updated Title"
      assert updated_document.icon == "📝"
      assert updated_document.color == "#FFFFFF"
    end

    test "update_document/2 with invalid data returns error changeset" do
      document = document_fixture()
      assert {:error, %Ecto.Changeset{}} = Core.Realtime.Documents.update_document(%{id: document.id, name: nil})
    end

    test "delete_document/1 deletes the document" do
      document = document_fixture()
      assert {:ok, %Document{}} = Core.Realtime.Documents.delete_document(document.id)
      assert {:error, :not_found} = Core.Realtime.Documents.get_document(document.id)
    end

    test "list_documents/0 returns all documents" do
      document = document_fixture()
      assert [doc] = Core.Realtime.Documents.list_by_organization(document.organization_id, document.tenant)
      assert doc.id == document.id
    end

    test "get_document/1 returns the document with given id" do
      document = document_fixture()
      assert {:ok, found_document} = Core.Realtime.Documents.get_document(document.id)
      assert found_document.id == document.id
    end

    test "changeset/2 returns a document changeset" do
      document = document_fixture()
      assert %Ecto.Changeset{} = Document.changeset(document, %{})
    end
  end
end
