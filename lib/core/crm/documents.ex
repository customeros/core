defmodule Core.Crm.Documents do
  @moduledoc """
  The Documents context.
  """
  import Ecto.Query, warn: false
  require Logger
  alias Core.Repo
  alias Core.Crm.Documents.{Document, RefDocument, DocumentWithLead}
  alias Core.Crm.{Leads.Lead, Companies.Company}
  alias Core.Utils.Media.Images

  @default_company_name "CustomerOS"
  @default_logo_path Application.app_dir(
                       :core,
                       "priv/static/images/customeros.png"
                     )

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

  def convert_all_documents_to_pdf(tenant_id) do
    case list_all_by_tenant(tenant_id) do
      {:ok, documents} ->
        results =
          documents
          |> Enum.map(fn doc_with_lead ->
            case get_document(doc_with_lead.document_id) do
              {:ok, document} ->
                case convert_to_pdf(document) do
                  {:ok, pdf_content} -> {:ok, {document, pdf_content}}
                  error -> error
                end

              error ->
                error
            end
          end)

        # Check if all conversions were successful
        if Enum.all?(results, &match?({:ok, _}, &1)) do
          {:ok, Enum.map(results, fn {:ok, result} -> result end)}
        else
          {:error, "Some documents failed to convert to PDF"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # === PDF Conversion ===

  def convert_to_pdf(%Document{} = document) do
    with {:ok, content} <- extract_document_content(document),
         {:ok, html, _} <- Earmark.as_html(content),
         html_with_style <- add_pdf_styles(html),
         {:ok, header_path} <- create_header_file(document),
         {:ok, footer_path} <- create_footer_file(),
         {:ok, pdf} <- generate_pdf(html_with_style, header_path, footer_path) do
      cleanup_temp_files([header_path, footer_path])
      {:ok, pdf}
    else
      {:error, reason} ->
        cleanup_all_temp_files()
        Logger.error("PDF generation failed: #{inspect(reason)}")
        {:error, "Could not generate PDF: #{inspect(reason)}"}
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

  # === Private Functions - Content Processing ===

  defp extract_document_content(%Document{lexical_state: nil, body: body}),
    do: {:ok, body}

  defp extract_document_content(%Document{lexical_state: state, body: body}) do
    case Jason.decode(state) do
      {:ok, %{"root" => %{"children" => children}}} ->
        markdown = convert_lexical_to_markdown(children)
        {:ok, markdown}

      _ ->
        {:ok, body}
    end
  end

  defp convert_lexical_to_markdown(children) do
    children
    |> Enum.map(&convert_lexical_node/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp convert_lexical_node(%{
         "type" => "heading",
         "tag" => tag,
         "children" => [%{"text" => text} | _]
       }) do
    level = String.to_integer(String.replace(tag, "h", ""))
    String.duplicate("#", level) <> " " <> text
  end

  defp convert_lexical_node(%{
         "type" => "paragraph",
         "children" => [%{"text" => text} | _]
       }) do
    text
  end

  defp convert_lexical_node(_), do: ""

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

  # === Private Functions - PDF Generation ===

  defp create_header_file(document) do
    with {:ok, html} <- generate_header_html(document),
         {:ok, temp_path} <- Temp.path(%{suffix: ".html"}),
         :ok <- File.write(temp_path, html) do
      {:ok, temp_path}
    else
      error ->
        Logger.error("Header creation failed: #{inspect(error)}")
        {:error, "Failed to create header file: #{inspect(error)}"}
    end
  end

  defp create_footer_file do
    with html <- generate_footer_html(),
         {:ok, temp_path} <- Temp.path(%{suffix: ".html"}),
         :ok <- File.write(temp_path, html) do
      {:ok, temp_path}
    else
      error ->
        Logger.error("Footer creation failed: #{inspect(error)}")
        {:error, "Failed to create footer file: #{inspect(error)}"}
    end
  end

  defp generate_pdf(html_content, header_path, footer_path) do
    PdfGenerator.generate_binary(html_content,
      page_size: "A4",
      zoom: 1.0,
      shell_params: [
        "--encoding",
        "UTF-8",
        "--margin-top",
        "40",
        "--margin-right",
        "20",
        "--margin-bottom",
        "20",
        "--margin-left",
        "20",
        "--header-html",
        header_path,
        "--header-spacing",
        "0",
        "--footer-html",
        footer_path,
        "--footer-spacing",
        "0",
        "--disable-smart-shrinking",
        "--print-media-type",
        "--enable-local-file-access",
        "--no-stop-slow-scripts",
        "--javascript-delay",
        "1000",
        "--load-error-handling",
        "ignore",
        "--load-media-error-handling",
        "ignore"
      ]
    )
  end

  # === Private Functions - HTML Generation ===

  defp generate_header_html(document) do
    with {:ok, lead} <- get_lead_for_document(document.id),
         {:ok, company} <- get_company_for_lead(lead.ref_id),
         {:ok, logo_info} <- prepare_logo(company) do
      {:ok, create_header_html_template(logo_info.path, logo_info.company_name)}
    else
      _ ->
        {:ok,
         create_header_html_template(@default_logo_path, @default_company_name)}
    end
  end

  defp get_lead_for_document(document_id) do
    query =
      from l in Lead,
        join: rd in RefDocument,
        on: rd.ref_id == l.id,
        where: rd.document_id == ^document_id,
        select: %{id: l.id, ref_id: l.ref_id}

    case Repo.one(query) do
      nil -> {:error, :lead_not_found}
      lead -> {:ok, lead}
    end
  end

  defp get_company_for_lead(lead_ref_id) do
    query =
      from c in Company,
        where: c.id == ^lead_ref_id,
        select: %{name: c.name, icon_key: c.icon_key}

    case Repo.one(query) do
      nil -> {:error, :company_not_found}
      company -> {:ok, company}
    end
  end

  @default_logo_path Application.app_dir(
                       :core,
                       "priv/static/images/customeros.png"
                     )

  defp prepare_logo(%{name: name, icon_key: nil}),
    do: {:ok, %{path: @default_logo_path, company_name: name}}

  defp prepare_logo(%{name: name, icon_key: icon_key})
       when is_binary(icon_key) do
    case download_and_prepare_logo(icon_key) do
      {:ok, logo_path} ->
        {:ok, %{path: logo_path, company_name: name}}

      {:error, _reason} ->
        {:ok, %{path: @default_logo_path, company_name: name}}
    end
  end

  defp prepare_logo(_), do: {:error, :invalid_company_info}

  defp download_and_prepare_logo(icon_key) do
    with {:ok, cdn_url} <- get_cdn_url(icon_key),
         {:ok, image_data} <- Images.download_image(cdn_url),
         {:ok, temp_path} <- create_temp_file(cdn_url),
         :ok <- File.write(temp_path, image_data),
         {:ok, _} <- File.stat(temp_path),
         {:ok, png_path} <- convert_jpg_to_png(temp_path, temp_path),
         {:ok, final_path} <- copy_to_temp_dir(temp_path) do
      # Always cleanup temp files after processing
      Enum.each([temp_path], &cleanup_temp_file/1)

      {:ok, final_path}
    else
      _ -> {:error, :logo_download_failed}
    end
  end

  def convert_jpg_to_png(input_path, output_path) do
    try do
      input_path
      |> Mogrify.open()
      |> Mogrify.format("png")
      |> Mogrify.save(path: output_path)

      {:ok, output_path}
    rescue
      error -> {:error, "Conversion failed: #{inspect(error)}"}
    end
  end

  defp get_cdn_url(icon_key) do
    case Images.get_cdn_url(icon_key) do
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, :invalid_cdn_url}
    end
  end

  defp create_temp_file(url) do
    # Remove query parameters and force .png extension
    clean_url = url |> String.split("?") |> List.first()

    case Temp.path(%{suffix: ".png"}) do
      {:ok, path} -> {:ok, path}
      _ -> {:error, :temp_file_creation_failed}
    end
  end

  defp copy_to_temp_dir(source_path) do
    with {:ok, temp_dir} <- Temp.mkdir() do
      try do
        extension = Path.extname(source_path)
        dest_path = Path.join(temp_dir, "logo#{extension}")
        File.cp!(source_path, dest_path)
        {:ok, dest_path}
      rescue
        _ ->
          Logger.error("Copy to temp dir failed: #{source_path}")
          {:error, :copy_failed}
      end
    else
      _ ->
        Logger.error("Creation of temp dir failed: #{source_path}")
        {:error, :temp_dir_creation_failed}
    end
  end

  defp cleanup_temp_file(path) do
    if String.contains?(path, "/tmp/") do
      File.rm(path)
    end
  end

  defp create_header_html_template(image_path, company_name) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
      #{header_css_styles()}
    </head>
    <body>
      <div class="header">
        <img src="file://#{image_path}" alt="#{company_name} Logo" />
        <span>#{company_name} Account Brief</span>
      </div>
    </body>
    </html>
    """
  end

  defp generate_footer_html do
    logo_base64 = File.read!(@default_logo_path) |> Base.encode64()

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      #{footer_css_styles()}
    </head>
    <body>
      <div class="footer">
        <img src="data:image/png;base64,#{logo_base64}" alt="CustomerOS Logo" />
        <span>CustomerOS</span>
      </div>
    </body>
    </html>
    """
  end

  defp add_pdf_styles(html) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      #{pdf_content_css_styles()}
    </head>
    <body>
      <div class="content">
        #{html}
      </div>
    </body>
    </html>
    """
  end

  # === CSS Styles ===

  defp header_css_styles do
    """
    <style>
      @page {
        margin: 0;
        padding: 0;
      }
      body {
        margin: 0;
        padding: 0;
        font-family: Arial, sans-serif;
      }
      .header {
        height: 50px;
        padding: 15px 20px 0 20px;
        border-bottom: 1px solid #eee;
        background: white;
        box-sizing: border-box;
      }
      .header img {
        height: 24px;
        width: auto;
        vertical-align: middle;
        display: inline-block;
        max-width: 200px;
      }
      .header span {
        font-size: 14px;
        vertical-align: middle;
        margin-left: 10px;
        font-weight: bold;
        display: inline-block;
      }
    </style>
    """
  end

  defp footer_css_styles do
    """
    <style>
      body {
        margin: 0;
        padding: 0;
      }
      .footer {
        height: 50px;
        padding: 15px 20px 0 20px;
        border-top: 1px solid #eee;
        background: white;
      }
      .footer img {
        height: 24px;
        vertical-align: middle;
      }
      .footer span {
        font-size: 10px;
        vertical-align: middle;
        margin-left: 10px;
      }
    </style>
    """
  end

  defp pdf_content_css_styles do
    """
    <style>
      @page {
        margin: 20mm;
        size: A4;
      }
      body {
        font-family: "IBM Plex Sans", sans-serif;
        line-height: 1.6;
        color: #333;
        max-width: 800px;
        margin: 0 auto;
        padding: 20px;
        position: relative;
        min-height: 100vh;
      }
      h1, h2 {
        font-weight: bold;
      }
      .content {
        margin-bottom: 100px;
      }
    </style>
    """
  end

  # === Cleanup Functions ===

  defp cleanup_temp_files(paths) do
    Enum.each(paths, &File.rm/1)
  end

  defp cleanup_all_temp_files do
    if temp_dir = Process.get(:temp_dir) do
      File.rm_rf!(temp_dir)
    end
  end

  # === DTO Conversion ===

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
