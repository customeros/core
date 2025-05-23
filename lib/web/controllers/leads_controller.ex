defmodule Web.LeadsController do
  use Web, :controller
  alias Core.Crm.Leads

  def index(conn, _params) do
    %{tenant_id: tenant_id} = conn.assigns.current_user
    companies = Leads.list_view_by_tenant_id(tenant_id)

    conn
    |> assign_prop(:companies, companies)
    |> render_inertia("Leads")
  end
end
