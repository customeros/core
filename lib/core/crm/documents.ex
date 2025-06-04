defmodule Core.Crm.Documents do
  @moduledoc """
  The Documents context.
  """
  import Ecto.Query, warn: false
  require Logger
  alias Core.Repo
  alias Core.Crm.Documents.{Document, RefDocument}

  def create_document(attrs \\ %{}, opts \\ []) do
    attrs
    |> prepare_payload(opts)
    |> create_document_with_lexical_state()
  end

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

  def update_document(attrs \\ %{}) do
    case Repo.get(Document, attrs.id) do
      %Document{} = document ->
        document
        |> Document.update_changeset(attrs)
        |> Repo.update()

      nil ->
        {:error, :not_found}
    end
  end

  def delete_document(id) do
    case Repo.get(Document, id) do
      %Document{} = document ->
        Repo.delete(document)

      nil ->
        {:error, :not_found}
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
    case Repo.get(Document, id) do
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

  def convert_to_pdf(%Document{} = document) do
    with {:ok, html, _} <- Earmark.as_html(document.body),
         html_with_style <- add_pdf_styles(html),
         {:ok, pdf} <-
           PdfGenerator.generate(html_with_style, page_size: "A4", zoom: 1.0) do
      {:ok, pdf}
    else
      {:error, reason} ->
        Logger.error("PDF generation failed: #{inspect(reason)}")
        {:error, "Could not generate PDF"}
    end
  end

  defp add_pdf_styles(html) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body {
          font-family: "IBM Plex Sans Regular", "Inter Medium", "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
          line-height: 1.6;
          color: #333;
          max-width: 800px;
          margin: 0 auto;
          padding: 20px;
        }
        h1 {
          font-size: 20px;
          margin-bottom: 20px;
          font-family: "IBM Plex Sans Bold", "Inter SemiBold", "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }
        h2 {
          font-size: 16px;
          margin-top: 30px;
          margin-bottom: 15px;
          font-family: "IBM Plex Sans Bold", "Inter SemiBold", "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }
        p {
          margin-bottom: 15px;
          font-family: "IBM Plex Sans Regular", "Inter Medium", "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }
        ul, ol {
          margin-bottom: 15px;
          padding-left: 20px;
          font-family: "IBM Plex Sans Regular", "Inter Medium", "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }
        li {
          margin-bottom: 5px;
          font-family: "IBM Plex Sans Regular", "Inter Medium", "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }
        strong {
          font-family: "IBM Plex Sans Bold", "Inter SemiBold", "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }
        b {
          font-family: "IBM Plex Sans Bold", "Inter SemiBold", "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }
        em {
          font-family: "IBM Plex Sans Regular", "Inter Medium", "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
          font-style: italic;
        }
      </style>
    </head>
    <body>
      #{html}
    </body>
    </html>
    """
  end

  def list_all_by_tenant(tenant_id) do
    from(d in Document, where: d.tenant_id == ^tenant_id)
    |> Repo.all()
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
end
