defmodule Web.LeadsController do
  use Web, :controller
  alias Core.Crm.Leads
  alias CSV

  def index(conn, _params) do
    %{tenant_id: tenant_id} = conn.assigns.current_user
    companies = Leads.list_view_by_tenant_id(tenant_id)

    conn
    |> assign_prop(:companies, companies)
    |> render_inertia("Leads")
  end

  def download(conn, _params) do
    %{tenant_id: tenant_id} = conn.assigns.current_user
    companies = Leads.list_view_by_tenant_id(tenant_id)

    # Generate CSV content
    csv_content =
      companies
      |> Enum.map(fn company ->
        %{
          "name" => company.name,
          "country" => company.country,
          "country_name" => company.country_name,
          "domain" => company.domain,
          "industry" => company.industry,
          "stage" => company.stage
        }
      end)
      |> CSV.encode(
        headers: [
          "name",
          "country",
          "country_name",
          "domain",
          "industry",
          "stage"
        ]
      )
      |> Enum.to_list()
      |> Enum.join("\n")

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=leads.csv")
    |> send_resp(200, csv_content)
  end
end
