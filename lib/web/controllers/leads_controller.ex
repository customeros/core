defmodule Web.LeadsController do
  use Web, :controller
  require OpenTelemetry.Tracer
  alias Core.Crm.Leads
  alias Core.Stats
  alias CSV

  def index(conn, _params) do
    OpenTelemetry.Tracer.with_span "web.leads_controller:index" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.id", conn.assigns.current_user.tenant_id},
        {"user.id", conn.assigns.current_user.id}
      ])

      %{tenant_id: tenant_id} = conn.assigns.current_user
      companies = Leads.list_view_by_tenant_id(tenant_id)

      profile =
        case Core.Researcher.IcpProfiles.get_by_tenant_id(tenant_id) do
          {:ok, icp} ->
            %{
              profile: icp.profile,
              qualifying_attributes: icp.qualifying_attributes
            }

          _ ->
            nil
        end

      conn
      |> assign_prop(:companies, companies)
      |> assign_prop(:profile, profile)
      |> render_inertia("Leads")
    end
  end

  def download(conn, _params) do
    %{tenant_id: tenant_id, id: user_id} = conn.assigns.current_user
    companies = Leads.list_view_by_tenant_id(tenant_id)

    base_url = "#{conn.scheme}://#{get_req_header(conn, "host")}"

    # Generate CSV content
    csv_content =
      companies
      |> Enum.map(fn company ->
        %{
          "Name" => company.name,
          "Country Code" => company.country,
          "Country Name" => company.country_name,
          "Domain" => company.domain,
          "Industry" => company.industry,
          "Stage" => company.stage,
          "ICP Fit" => company.icp_fit,
          "Company Report" =>
            case company.document_id do
              nil -> nil
              _ -> "#{base_url}/documents/#{company.document_id}"
            end
        }
      end)
      |> CSV.encode(
        headers: [
          "Name",
          "Country Code",
          "Country Name",
          "Domain",
          "Industry",
          "Stage",
          "ICP Fit",
          "Company Report"
        ]
      )
      |> Enum.to_list()
      |> Enum.join("\n")

    Stats.register_event_start(user_id, :download_document)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=leads.csv")
    |> send_resp(200, csv_content)
  end
end
