defmodule Core.Crm.Documents do
  @moduledoc """
  The Documents context.
  """
  import Ecto.Query, warn: false
  require Logger
  alias Core.Repo
  alias Core.Crm.Documents.{Document, RefDocument}

  def create_document(attrs \\ %{}, opts \\ []) do
    parseDto = Keyword.get(opts, :parseDto, false)

    payload =
      case parseDto do
        true -> fromDto(attrs)
        _ -> attrs
      end

    ref_id = Map.get(payload, :ref_id)

    lexical_state =
      case Map.get(payload, :lexical_state, nil) do
        nil ->
          case Map.get(payload, :body, nil) do
            nil ->
              nil

            body ->
              case convert_md_to_lexical(body) do
                {:ok, state} ->
                  state

                {:error, _} ->
                  nil
              end
          end

        existing_lexical_state ->
          existing_lexical_state
      end

    payload_with_lexical_state = Map.put(payload, :lexical_state, lexical_state)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :document,
      Document.changeset(%Document{}, payload_with_lexical_state)
    )
    |> maybe_insert_ref_document(ref_id)
    |> maybe_initialize_ydoc(lexical_state)
    |> Repo.transaction()
    |> case do
      {:ok, %{document: document} = result} ->
        decorated_doc = %Document{document | ref_id: ref_id}
        {:ok, Map.put(result, :document, decorated_doc)}

      error ->
        error
    end
  end

  def update_document(attrs \\ %{}) do
    with %Document{} = document <- Repo.get(Document, attrs.id) do
      document
      |> Document.update_changeset(attrs)
      |> Repo.update()
    else
      nil -> {:error, :not_found}
    end
  end

  def delete_document(id) do
    with %Document{} = document <- Repo.get(Document, id) do
      document
      |> Repo.delete()
    else
      nil -> {:error, :not_found}
    end
  end

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

  def get_document(id) do
    query =
      from(d in Document,
        join: od in OrganizationDocument,
        on: d.id == od.document_id,
        where: d.id == ^id,
        select: merge(d, %{organization_id: od.organization_id}),
        limit: 1
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      doc -> {:ok, doc}
    end
  end

  defp initialize_y_writing(doc_id, lexical_state) do
    script_path =
      Application.app_dir(:core, "priv/scripts/convert_lexical_to_yjs")

    # Create a temporary file for the lexical state
    {:ok, temp_path} = Temp.path(%{suffix: ".json"})
    File.write!(temp_path, lexical_state)

    try do
      case System.cmd("sh", ["-c", "#{script_path} #{doc_id} @#{temp_path}"],
             stderr_to_stdout: true
           ) do
        {output, 0} ->
          Logger.info("Successfully converted lexical state to Yjs document")

          Core.Crm.Documents.YDoc.insert_update(doc_id, output)

        {error_output, exit_code} ->
          Logger.error(
            "Script execution failed (exit #{exit_code}): #{error_output}"
          )

          {:error, "Could not convert lexical state to Yjs document"}
      end
    after
      File.rm(temp_path)
    end
  end

  defp convert_md_to_lexical(md_content) do
    script_path =
      Application.app_dir(:core, "priv/scripts/convert_md_to_lexical")

    # Create a temporary file for the markdown content
    {:ok, temp_path} = Temp.path(%{suffix: ".md"})
    File.write!(temp_path, md_content)

    try do
      # Pass the file path directly without the @ symbol
      case System.cmd("sh", ["-c", "#{script_path} #{temp_path}"],
             stderr_to_stdout: true
           ) do
        {output, 0} ->
          Logger.info("Successfully converted markdown to lexical state")
          {:ok, output}

        {error_output, exit_code} ->
          Logger.error(
            "Script execution failed (exit #{exit_code}): #{error_output}"
          )

          {:error, "Could not convert markdown to lexical state"}
      end
    after
      File.rm(temp_path)
    end
  end

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

  defp fromDto(dto) do
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
end
