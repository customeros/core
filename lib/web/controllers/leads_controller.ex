defmodule Web.LeadsController do
  use Web, :controller
  require OpenTelemetry.Tracer
  alias Core.Crm.Leads
  alias Core.Stats
  alias CSV
  alias Core.Crm.Contacts

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

      personas =
        case params["lead"] do
          nil ->
            []

          lead_id ->
            Contacts.get_target_persona_contacts_by_lead_id(tenant_id, lead_id)
        end

      {attribution, attributions_list} =
        case params["lead"] do
          nil ->
            {nil, []}

          lead_id ->
            data = Leads.get_channel_attribution(tenant_id, lead_id)
            {data |> Enum.at(0), data}
        end

      conn
      |> assign_prop(:page_title, "Leads | CustomerOS")
      |> assign_prop(:leads, leads)
      |> assign_prop(:profile, profile)
      |> assign_prop(:stage_counts, stage_counts)
      |> assign_prop(:max_count, max_count)
      |> assign_prop(:personas, personas)
      |> assign_prop(:attribution, attribution)
      |> assign_prop(:attributions_list, attributions_list)
      |> render_inertia("Leads")
    end
  end

  def download(conn, _params) do
    %{tenant_id: tenant_id, id: user_id} = conn.assigns.current_user

    lead_contact_pairs =
      Leads.get_leads_by_tenant_id_with_target_personas(tenant_id)

    base_url = "#{conn.scheme}://#{get_req_header(conn, "host")}"

    headers = [
      "Lead Name",
      "Country Code",
      "Country Name",
      "Lead Domain",
      "Industry",
      "Stage",
      "ICP Fit",
      "Account Brief",
      "Created",
      "First Name",
      "Last Name",
      "Job Title",
      "Phone Number",
      "Email",
      "Linkedin URL"
    ]

    csv_content =
      lead_contact_pairs
      |> Enum.map(fn {contact, lead, company, document_id} ->
        %{
          "Lead Name" => company && company.name,
          "Lead Domain" => company && company.primary_domain,
          "Industry" => company && company.industry,
          "Country Code" => company && company.country_a2,
          "Country Name" =>
            case Countriex.get_by(:alpha2, company && company.country_a2) do
              %{name: name} -> name
              _ -> nil
            end,
          "Stage" => format_stage(lead.stage),
          "ICP Fit" => lead.icp_fit |> Atom.to_string() |> String.capitalize(),
          "Account Brief" =>
            case document_id do
              nil -> nil
              _ -> "#{base_url}/documents/#{document_id}"
            end,
          "Created" =>
            case lead.inserted_at do
              %DateTime{} = datetime ->
                datetime |> DateTime.to_date() |> Date.to_string()

              _ ->
                nil
            end,
          "First Name" => if(contact, do: contact.first_name, else: nil),
          "Last Name" => if(contact, do: contact.last_name, else: nil),
          "Job Title" => if(contact, do: contact.job_title, else: nil),
          "Linkedin URL" =>
            if(contact && contact.linkedin_id,
              do: "https://linkedin.com/in/" <> contact.linkedin_id,
              else: nil
            ),
          "Email" => if(contact, do: contact.business_email, else: nil),
          "Phone Number" => if(contact, do: contact.mobile_phone, else: nil)
        }
      end)
      |> CSV.encode(headers: headers)
      |> Enum.to_list()
      |> Enum.join()

    Stats.register_event_start(user_id, :download_document)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=leads.csv")
    |> send_resp(200, csv_content)
  end

  def disqualify(conn, %{"id" => lead_id}) do
    %{tenant_id: tenant_id} = conn.assigns.current_user

    case Leads.disqualify_lead_by_user(tenant_id, lead_id) do
      {:ok, lead} ->
        lead_map =
          Map.take(lead, [
            :id,
            :tenant_id,
            :ref_id,
            :type,
            :stage,
            :icp_fit,
            :icp_disqualification_reason,
            :error_message,
            :icp_fit_evaluation_attempt_at,
            :icp_fit_evaluation_attempts,
            :brief_create_attempt_at,
            :brief_create_attempts,
            :just_created,
            :inserted_at,
            :updated_at
          ])

        conn
        |> put_status(:ok)
        |> json(%{success: true, lead: lead_map})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Lead not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to disqualify lead: #{reason}"})
    end
  end

  def set_state(conn, %{"id" => lead_id, "state" => state}) do
    case Leads.update_lead_field(
           lead_id,
           %{state: state |> String.to_atom()},
           "state"
         ) do
      {:ok, updated_lead} ->
        lead_map =
          Map.take(updated_lead, [
            :id,
            :tenant_id,
            :ref_id,
            :type,
            :stage,
            :icp_fit,
            :icp_disqualification_reason,
            :error_message,
            :icp_fit_evaluation_attempt_at,
            :icp_fit_evaluation_attempts,
            :brief_create_attempt_at,
            :brief_create_attempts,
            :just_created,
            :state,
            :inserted_at,
            :updated_at
          ])

        conn
        |> put_status(:ok)
        |> json(%{success: true, lead: lead_map})

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to update lead state"})
    end
  end

  defp get_filter_by(params) do
    case params do
      %{"stage" => stage} -> [stage: stage]
      _ -> [stage: "target"]
    end
  end

  defp get_order_by(params) do
    order_mapping = %{
      "asc" => %{
        "stage" => [asc: :stage],
        "updated_at" => [asc: :updated_at],
        "name" => [asc: :name],
        "industry" => [asc: :industry],
        "country" => [asc: :country]
      },
      "desc" => %{
        "stage" => [desc: :stage],
        "updated_at" => [desc: :updated_at],
        "name" => [desc: :name],
        "industry" => [desc: :industry],
        "country" => [desc: :country]
      }
    }

    case params do
      %{"asc" => field}
      when field in ["stage", "updated_at", "name", "industry", "country"] ->
        order_mapping["asc"][field] || [desc: :updated_at]

      %{"desc" => field}
      when field in ["stage", "updated_at", "name", "industry", "country"] ->
        order_mapping["desc"][field] || [desc: :updated_at]

      _ ->
        [desc: :updated_at]
    end
  end

  defp get_group_by(params) do
    case params do
      %{"group" => "stage"} -> :stage
      %{"group" => "none"} -> nil
      _ -> nil
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
      :pending -> "Pending"
      nil -> ""
      _ -> stage |> Atom.to_string() |> String.capitalize()
    end
  end
end
