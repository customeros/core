defmodule Core.Crm.Documents do
  @moduledoc """
  The Documents context.
  """
  import Ecto.Query, warn: false
  require Logger
  alias Core.Repo
  alias Core.Crm.Documents.{Document, RefDocument, DocumentWithLead}

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
          Core.Crm.Documents.YDoc.insert_update(doc_id, output)

        {error_output, exit_code} ->
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
          {:ok, output}

        {error_output, exit_code} ->
          {:error, "Could not convert markdown to lexical state"}
      end
    after
      File.rm(temp_path)
    end
  end

  defp generate_header_html(document) do
    # Get the lead through RefDocument
    lead =
      from(l in Core.Crm.Leads.Lead,
        join: rd in RefDocument,
        on: rd.ref_id == l.id,
        where: rd.document_id == ^document.id,
        select: %{id: l.id, ref_id: l.ref_id}
      )
      |> Repo.one()

    # Get company information if lead exists
    company_info =
      if lead do
        from(c in Core.Crm.Companies.Company,
          where: c.id == ^lead.ref_id,
          select: %{name: c.name, icon_key: c.icon_key}
        )
        |> Repo.one()
      end

    # Use company info if available, otherwise fallback to default
    {logo_path, company_name} =
      if company_info && company_info.name do
        if company_info.icon_key do
          case Core.Utils.Media.Images.get_cdn_url(company_info.icon_key) do
            url when is_binary(url) ->
              extension = Path.extname(url)
              {:ok, temp_path} = Temp.path(%{suffix: extension})

              case Core.Utils.Media.Images.download_image(url) do
                {:ok, image_data} ->
                  case File.write(temp_path, image_data) do
                    :ok ->
                      case File.stat(temp_path) do
                        {:ok, _stat} ->
                          {temp_path, company_info.name}

                        _ ->
                          {Application.app_dir(
                             :core,
                             "priv/static/images/customeros.png"
                           ), company_info.name}
                      end

                    _ ->
                      {Application.app_dir(
                         :core,
                         "priv/static/images/customeros.png"
                       ), company_info.name}
                  end

                _ ->
                  {Application.app_dir(
                     :core,
                     "priv/static/images/customeros.png"
                   ), company_info.name}
              end

            _ ->
              {Application.app_dir(:core, "priv/static/images/customeros.png"),
               company_info.name}
          end
        else
          {Application.app_dir(:core, "priv/static/images/customeros.png"),
           company_info.name}
        end
      else
        default_path =
          Application.app_dir(:core, "priv/static/images/customeros.png")

        {default_path, "CustomerOS"}
      end

    # Create a temporary directory for the image
    {:ok, temp_dir} = Temp.mkdir()
    image_path = Path.join(temp_dir, "logo#{Path.extname(logo_path)}")
    File.cp!(logo_path, image_path)
    IO.puts("Image copied to temp: #{image_path}")
    # Clean up the original temporary file if it was created
    if String.contains?(logo_path, "/tmp/") do
      File.rm(logo_path)
    end

    # Determine mime type based on extension
    extension =
      Path.extname(image_path) |> String.trim_leading(".") |> String.downcase()

    mime_type =
      case extension do
        "png" -> "image/png"
        "jpg" -> "image/jpeg"
        "jpeg" -> "image/jpeg"
        "gif" -> "image/gif"
        _ -> "application/octet-stream"
      end

    # Read image and encode to base64
    logo_data = File.read!(image_path) |> Base.encode64()
    IO.puts("Logo data: #{logo_data}")
    logo_base64 = "data:#{mime_type};base64,#{logo_data}"

    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
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
    </head>
    <body>
      <div class="header">
    <img src="file://#{image_path}" alt="#{company_name} Logo" />
    <span>#{company_name} Report</span>
      </div>
    </body>
    </html>
    """
  end

  defp generate_footer_html() do
    logo_path = Application.app_dir(:core, "priv/static/images/customeros.png")
    logo_base64 = File.read!(logo_path) |> Base.encode64()

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
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
    </head>
    <body>
      <div class="content">
        #{html}
      </div>
    </body>
    </html>
    """
  end

  def convert_to_pdf(%Document{} = document) do
    content =
      case document.lexical_state do
        nil ->
          document.body

        state ->
          case Jason.decode(state) do
            {:ok, %{"root" => %{"children" => children}}} ->
              markdown =
                children
                |> Enum.map(fn
                  %{
                    "type" => "heading",
                    "tag" => tag,
                    "children" => [%{"text" => text} | _]
                  } ->
                    level = String.to_integer(String.replace(tag, "h", ""))
                    String.duplicate("#", level) <> " " <> text

                  %{
                    "type" => "paragraph",
                    "children" => [%{"text" => text} | _]
                  } ->
                    text

                  _ ->
                    ""
                end)
                |> Enum.join("\n\n")

              markdown

            _ ->
              document.body
          end
      end

    with {:ok, html, _} <- Earmark.as_html(content),
         html_with_style <- add_pdf_styles(html),
         footer_html <- generate_footer_html(),
         footer_path = "/tmp/pdf_footer.html",
         :ok <- File.write(footer_path, footer_html),
         header_html <- generate_header_html(document),
         dbg(header_html),
         header_path = "/tmp/pdf_header.html",
         :ok <- File.write(header_path, header_html),
         {:ok, pdf} <-
           PdfGenerator.generate_binary(html_with_style,
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
           ) do
      # Clean up temporary files
      File.rm(footer_path)
      File.rm(header_path)

      if temp_dir = Process.get(:temp_dir) do
        File.rm_rf!(temp_dir)
      end

      {:ok, pdf}
    else
      {:error, reason} ->
        # Clean up temporary files even on error
        if temp_dir = Process.get(:temp_dir) do
          File.rm_rf!(temp_dir)
        end

        {:error, "Could not generate PDF"}
    end
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
