defmodule Web.LeadsController do
  use Web, :controller
  require OpenTelemetry.Tracer
  alias Core.Crm.Leads
  alias Core.Stats
  alias CSV

  def index(conn, params) do
    OpenTelemetry.Tracer.with_span "web.leads_controller:index" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.id", conn.assigns.current_user.tenant_id},
        {"user.id", conn.assigns.current_user.id}
      ])

      %{tenant_id: tenant_id} = conn.assigns.current_user

      %{data: leads, stage_counts: stage_counts, max_count: max_count} =
        Leads.list_view_by_tenant_id(
          tenant_id,
          get_order_by(params),
          get_group_by(params),
          get_filter_by(params)
        )

      profile =
        case Core.Researcher.IcpProfiles.get_by_tenant_id(tenant_id) do
          {:ok, profile} -> profile
          _ -> nil
        end

      conn
      |> assign_prop(:page_title, "Leads | CustomerOS")
      |> assign_prop(:leads, leads)
      |> assign_prop(:profile, profile)
      |> assign_prop(:stage_counts, stage_counts)
      |> assign_prop(:max_count, max_count)
      |> render_inertia("Leads")
    end
  end

  def download(conn, _params) do
    %{tenant_id: tenant_id, id: user_id} = conn.assigns.current_user
    %{data: leads} = Leads.list_view_by_tenant_id(tenant_id)

    base_url = "#{conn.scheme}://#{get_req_header(conn, "host")}"

    # Generate CSV content
    csv_content =
      leads
      |> Enum.map(fn lead ->
        %{
          "Name" => lead.name,
          "Country Code" => lead.country,
          "Country Name" => lead.country_name,
          "Domain" => lead.domain,
          "Industry" => lead.industry,
          "Stage" => format_stage(lead.stage),
          "ICP Fit" => lead.icp_fit |> Atom.to_string() |> String.capitalize(),
          "Account Brief" =>
            case lead.document_id do
              nil -> nil
              _ -> "#{base_url}/documents/#{lead.document_id}"
            end,
          "Created" =>
            case lead.inserted_at do
              %DateTime{} = datetime ->
                datetime |> DateTime.to_date() |> Date.to_string()

              _ ->
                nil
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
          "Account Brief",
          "Created"
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

  defp get_filter_by(params) do
    case params do
      %{"stage" => stage} -> [stage: stage]
      _ -> nil
    end
  end

  defp get_order_by(params) do
    order_mapping = %{
      "asc" => %{
        "stage" => [asc: :stage],
        "inserted_at" => [asc: :inserted_at],
        "name" => [asc: :name],
        "industry" => [asc: :industry],
        "country" => [asc: :country]
      },
      "desc" => %{
        "stage" => [desc: :stage],
        "inserted_at" => [desc: :inserted_at],
        "name" => [desc: :name],
        "industry" => [desc: :industry],
        "country" => [desc: :country]
      }
    }

    case params do
      %{direction => field} when direction in ["asc", "desc"] ->
        order_mapping[direction][field] || [desc: :inserted_at]

      _ ->
        [desc: :inserted_at]
    end
  end

  defp get_group_by(params) do
    case params do
      %{"group" => "stage"} -> :stage
      %{"group" => "none"} -> nil
      _ -> :stage
    end
  end

  defp format_stage(stage) do
    case stage do
      :target -> "Target"
      :education -> "Education"
      :solution -> "Solution"
      :evaluation -> "Evaluation"
      :ready_to_buy -> "Ready to Buy"
      :customer -> "Customer"
      :not_a_fit -> "Not a Fit"
      :pending -> "Pending"
      nil -> ""
      _ -> stage |> Atom.to_string() |> String.capitalize()
    end
  end
end
