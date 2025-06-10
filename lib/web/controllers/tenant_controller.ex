defmodule Web.TenantController do
  use Web, :controller

  def index(conn, _params) do
    tenants = Core.Auth.Tenants.get_all_tenants()

    conn
    |> put_status(:ok)
    |> json(tenants)
  end

  def switch(conn, %{"tenant_id" => new_tenant_id}) do
    current_user = conn.assigns.current_user

    case Core.Auth.Users.update_user_tenant_id(current_user, new_tenant_id) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Tenant switched successfully", user: updated_user})

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to update user"})
    end
  end
end
