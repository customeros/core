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

  def index(conn, %{"id" => id}) do
    case Documents.get_document(id) do
      {:ok, document} ->
        ref_id = Documents.get_ref_by_document_id(id) |> Map.get(:ref_id)

        case Core.Crm.Leads.get_view_by_id(ref_id) do
          {:ok, lead} ->
            conn
            |> assign_prop(:document, document)
            |> assign_prop(:lead, lead)
            |> render_inertia("Document")

          {:error, :not_found} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(404, Jason.encode!(%{error: "Lead not found"}))
        end

      {:error, _} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Document not found"}))
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
