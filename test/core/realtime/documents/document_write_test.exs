defmodule Core.Realtime.Documents.DocumentWriteTest do
  use Core.DataCase

  alias Core.Realtime.Documents.DocumentWrite

  describe "document_write" do
    import Core.Realtime.DocumentsFixtures

    test "changeset/2 with valid data returns a valid changeset" do
      document = document_fixture()
      valid_attrs = %{
        docName: document.id,
        value: "Updated content",
        version: "v1"
      }

      changeset = DocumentWrite.changeset(%DocumentWrite{}, valid_attrs)
      assert changeset.valid?
    end

    test "changeset/2 with invalid data returns an invalid changeset" do
      changeset = DocumentWrite.changeset(%DocumentWrite{}, %{})
      refute changeset.valid?
    end
  end
end
