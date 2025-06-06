defmodule Core.Crm.Documents do
  @moduledoc """
  The Documents context.
  """
  import Ecto.Query, warn: false
  require Logger
  alias Core.Repo
  alias Core.Crm.Documents.{Document, RefDocument, DocumentWithLead}

  # === Document CRUD Operations ===

  def create_document(attrs \\ %{}, opts \\ []) do
    attrs
    |> prepare_payload(opts)
    |> create_document_with_lexical_state()
  end

  def update_document(attrs \\ %{}) do
    case Repo.get(Document, attrs.id) do
      %Document{} = document ->
        document
        |> Document.update_changeset(attrs)
        |> Repo.update()

      nil ->
        Logger.error("Document not found")
        {:error, :not_found}
    end
  end

  def delete_document(id) do
    case Repo.get(Document, id) do
      %Document{} = document ->
        Repo.delete(document)

      nil ->
        Logger.error("Document not found")
        {:error, :not_found}
    end
  end

  def get_document(id) do
    case Repo.get(Document, id) do
      nil -> {:error, :not_found}
      doc -> {:ok, doc}
    end
  end

  # === Document Listing Functions ===

  def list_by_ref(ref_id, tenant_id) do
    from(d in Document,
      join: rd in RefDocument,
      on: d.id == rd.document_id,
      where: rd.ref_id == ^ref_id and d.tenant_id == ^tenant_id,
      select: %{
        id: d.id,
        name: d.name,
        icon: d.icon,
        color: d.color,
        tenant_id: d.tenant_id,
        user_id: d.user_id,
        ref_id: rd.ref_id,
        inserted_at: d.inserted_at,
        updated_at: d.updated_at
      }
    )
    |> Repo.all()
  end

  def get_ref_by_document_id(document_id) do
    from(rd in RefDocument,
      where: rd.document_id == ^document_id,
      select: rd
    )
    |> Repo.one()
  end

  def list_all_by_tenant(tenant_id) do
    query =
      from d in Document,
        join: rd in RefDocument,
        on: d.id == rd.document_id,
        where: d.tenant_id == ^tenant_id,
        select: %DocumentWithLead{
          document_id: d.id,
          document_name: d.name,
          body: d.body,
          tenant_id: d.tenant_id,
          lead_id: rd.ref_id
        }

    case Repo.all(query) do
      [] -> {:error, :not_found}
      documents -> {:ok, documents}
    end
  end

  # === Private Functions - Document Creation ===

  defp prepare_payload(attrs, opts) do
    parse_dto = Keyword.get(opts, :parse_dto, false)
    if parse_dto, do: from_dto(attrs), else: attrs
  end

  defp create_document_with_lexical_state(payload) do
    ref_id = Map.get(payload, :ref_id)
    lexical_state = get_lexical_state(payload)
    payload_with_lexical_state = Map.put(payload, :lexical_state, lexical_state)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :document,
      Document.changeset(%Document{}, payload_with_lexical_state)
    )
    |> maybe_insert_ref_document(ref_id)
    |> maybe_initialize_ydoc(lexical_state)
    |> Repo.transaction()
    |> handle_transaction_result(ref_id)
  end

  defp get_lexical_state(%{lexical_state: existing_state})
       when not is_nil(existing_state),
       do: existing_state

  defp get_lexical_state(%{body: body}) when not is_nil(body) do
    case convert_md_to_lexical(body) do
      {:ok, state} -> state
      {:error, _} -> nil
    end
  end

  defp get_lexical_state(_), do: nil

  defp handle_transaction_result({:ok, %{document: document} = result}, ref_id) do
    decorated_doc = %Document{document | ref_id: ref_id}

    case Core.Crm.Leads.get_by_id(document.tenant_id, ref_id) do
      {:ok, lead} ->
        Core.Crm.Leads.LeadNotifier.notify_lead_updated(lead)
        {:ok, lead}

      {:error, _} ->
        {:ok, decorated_doc}
    end

    {:ok, Map.put(result, :document, decorated_doc)}
  end

  defp handle_transaction_result(error, _ref_id), do: {:error, error}

  defp maybe_insert_ref_document(multi, nil), do: multi

  defp maybe_insert_ref_document(multi, ref_id) do
    Ecto.Multi.insert(multi, :ref_document, fn %{document: document} ->
      %RefDocument{}
      |> RefDocument.changeset(%{
        ref_id: ref_id,
        document_id: document.id
      })
    end)
  end

  defp maybe_initialize_ydoc(multi, nil), do: multi

  defp maybe_initialize_ydoc(multi, lexical_state) do
    Ecto.Multi.run(multi, :initialize_y_writing, fn _repo,
                                                    %{document: document} ->
      initialize_y_writing(document.id, lexical_state)
    end)
  end

  defp convert_md_to_lexical(md_content) do
    script_path =
      Application.app_dir(:core, "priv/scripts/convert_md_to_lexical")

    with {:ok, temp_path} <- Temp.path(%{suffix: ".md"}),
         :ok <- File.write(temp_path, md_content),
         {output, 0} <-
           System.cmd("sh", ["-c", "#{script_path} #{temp_path}"],
             stderr_to_stdout: true
           ) do
      File.rm(temp_path)
      {:ok, output}
    else
      {error_output, _exit_code} ->
        Logger.error(
          "Error converting markdown to lexical state: #{error_output}"
        )

        {:error, "Could not convert markdown to lexical state"}
    end
  end

  defp initialize_y_writing(doc_id, lexical_state) do
    script_path =
      Application.app_dir(:core, "priv/scripts/convert_lexical_to_yjs")

    with {:ok, temp_path} <- Temp.path(%{suffix: ".json"}),
         :ok <- File.write(temp_path, lexical_state),
         {output, 0} <-
           System.cmd("sh", ["-c", "#{script_path} #{doc_id} @#{temp_path}"],
             stderr_to_stdout: true
           ) do
      File.rm(temp_path)
      Core.Crm.Documents.YDoc.insert_update(doc_id, output)
    else
      {error_output, _exit_code} ->
        Logger.error("Error converting lexical state to Yjs: #{error_output}")
        {:error, "Could not convert lexical state to Yjs document"}
    end
  end

  defp from_dto(dto) do
    %{
      "name" => name,
      "userId" => user_id,
      "tenantId" => tenant_id,
      "body" => body,
      "icon" => icon,
      "color" => color
    } = dto

    ref_id = Map.get(dto, "refId", nil)

    lexical_state =
      case Map.get(dto, "lexicalState", nil) do
        nil -> nil
        value -> Jason.encode!(value)
      end

    %{
      name: name,
      body: body,
      user_id: user_id,
      tenant_id: tenant_id,
      icon: icon,
      color: color,
      lexical_state: lexical_state,
      ref_id: ref_id
    }
  end

  @doc """
  Migrates documents that have empty lexical_state by converting their body content
  to lexical state and initializing the YDoc.
  """
  def migrate_documents_lexical_state do
    # Get all documents with empty lexical_state
    documents =
      from(d in Document,
        where:
          (is_nil(d.lexical_state) or d.lexical_state == "") and
            (not is_nil(d.body) or d.body != "")
      )
      |> Repo.all()

    dbg(documents)

    Enum.each(documents, fn document ->
      # Convert body to lexical state
      case convert_md_to_lexical(document.body) do
        {:ok, lexical_state} ->
          # Delete existing document writes
          dbg(lexical_state)
          Core.Crm.Documents.YDoc.clear_document(document.id)

          # Initialize new YDoc with the converted lexical state
          case initialize_y_writing(document.id, lexical_state) do
            {:ok, _} ->
              # Update the document with the new lexical state
              update_document(%{
                id: document.id,
                lexical_state: lexical_state
              })

            {:error, error} ->
              Logger.error(
                "Failed to initialize YDoc for document #{document.id}: #{error}"
              )
          end

        {:error, error} ->
          Logger.error(
            "Failed to convert markdown to lexical state for document #{document.id}: #{error}"
          )
      end
    end)
  end
end
