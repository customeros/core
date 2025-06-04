defmodule Web.DocumentController do
  use Web, :controller
  require Logger
  import Plug.Conn
  alias Core.Crm.Documents

  def create(
        conn,
        %{
          "name" => _name,
          "body" => _body,
          "userId" => _user_id,
          "tenantId" => _tenant_id,
          "icon" => _icon,
          "color" => _color,
          "refId" => _ref_id
        } = params
      ) do
    handle_create(conn, params)
  end

  def create(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, Jason.encode!(%{error: "Invalid request body"}))
  end

  def index(conn, %{"refId" => ref_id}) do
    tenant_id = get_req_header(conn, "x-tenant") |> List.first()
    documents = Documents.list_by_ref(ref_id, tenant_id)

    json_response =
      documents
      |> Enum.map(fn doc ->
        if is_struct(doc), do: Map.from_struct(doc), else: doc
      end)
      |> Enum.map(&Core.Utils.MapUtils.to_camel_case_map/1)
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, json_response)
  end

  def download(conn, %{"id" => id}) do
    case Documents.get_document(id) do
      {:ok, doc} ->
        case Documents.convert_to_pdf(doc) do
          {:ok, pdf} ->
            conn
            |> put_resp_content_type("application/pdf")
            |> put_resp_header(
              "content-disposition",
              "attachment; filename=\"#{doc.name}.pdf\""
            )
            |> send_resp(200, pdf)

          {:error, _} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, Jason.encode!(%{error: "Could not generate PDF"}))
        end

      {:error, _} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Document not found"}))
    end
  end

  def download_all(conn, %{"tenant_id" => tenant_id}) do
    case Documents.convert_all_documents_to_pdf(tenant_id) do
      {:ok, document_pdf_pairs} ->
        # Create a zip file containing all PDFs
        zip_filename = "documents_#{tenant_id}.zip"
        zip_path = Path.join(System.tmp_dir!(), zip_filename)

        :zip.create(
          zip_path,
          Enum.map(document_pdf_pairs, fn {doc, pdf} ->
            {String.to_charlist("#{doc.name}.pdf"), pdf}
          end)
        )

        # Send the zip file
        conn
        |> put_resp_content_type("application/zip")
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"#{zip_filename}\""
        )
        |> send_file(200, zip_path)
        |> Plug.Conn.after_send(fn _conn ->
          File.rm(zip_path)
        end)

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          400,
          Jason.encode!(%{error: "Could not generate PDFs: #{reason}"})
        )
    end
  end

  defp handle_create(conn, params) do
    case Documents.create_document(params, parse_dto: true) do
      {:ok, %{document: document}} ->
        json_response =
          document
          |> Map.from_struct()
          |> Core.Utils.MapUtils.to_camel_case_map()
          |> Jason.encode!()

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(201, json_response)

      {:error, changeset} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          422,
          Jason.encode!(%{
            error: "Unprocessable entity",
            details: errors_from_changeset(changeset)
          })
        )
    end
  end

  defp errors_from_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
