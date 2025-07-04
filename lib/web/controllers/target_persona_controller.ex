defmodule Web.TargetPersonaController do
  use Web, :controller
  require Logger
  import Plug.Conn
  alias Core.Crm.TargetPersonas

  def create(
        conn,
        %{
          "tenant_id" => tenant_id,
          "linkedin_url" => linkedin_url
        } = _params
      ) do
    handle_create(conn, tenant_id, linkedin_url)
  end

  def create(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      400,
      Jason.encode!(%{
        error: "Invalid request body. Required fields: tenant_id, linkedin_url"
      })
    )
  end

  defp handle_create(conn, tenant_id, linkedin_url) do
    case TargetPersonas.create_from_linkedin(tenant_id, linkedin_url) do
      {:ok, personas} when is_list(personas) ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          201,
          Jason.encode!(%{
            message: "Target personas created successfully",
            count: length(personas)
          })
        )

      {:ok, _persona} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          201,
          Jason.encode!(%{message: "Target persona created successfully"})
        )

      {:error, :tenant_not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Tenant not found"}))

      {:error, :target_persona_creation_failed} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          422,
          Jason.encode!(%{error: "Failed to create target persona"})
        )

      {:error, reason} ->
        Logger.error("Target persona creation failed", %{
          tenant_id: tenant_id,
          linkedin_url: linkedin_url,
          reason: reason
        })

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{error: "Internal server error"}))
    end
  end
end
