Application.ensure_all_started(:core)

defmodule BriefCreator do
  require Logger
  require OpenTelemetry.Tracer
  alias Core.Crm.Leads
  alias Core.Crm.Documents
  alias Core.Researcher.BriefWriter
  alias Core.Crm.Companies

  def run_all(limit \\ 10) do
    Logger.info("Starting document creation process for leads without briefs")

    case get_icp_fits_without_brief_docs(limit) do
      {:error, :not_found} ->
        Logger.info("No leads found that need brief documents")

      {:ok, leads} ->
        Logger.info("Found #{length(leads)} leads that need brief documents")

        leads
        |> Enum.with_index(1)
        |> Enum.each(fn {lead, index} ->
          Logger.info("[#{index}/#{length(leads)}] Processing lead: #{lead.id}")
          process_lead(lead)
        end)

        Logger.info("Completed processing all leads")
    end
  end

  def run(lead_id) do
    case Leads.get_by_id(lead_id) do
      {:ok, lead} -> process_lead(lead)
      {:error, reason} -> Logger.error("Lead not found: #{reason}")
    end
  end

  defp process_lead(lead_record) do
    OpenTelemetry.Tracer.with_span "document_creator.process_lead" do
      OpenTelemetry.Tracer.set_attributes([
        {"lead.id", lead_record.id}
      ])

      # Check if documents already exist for this lead
      case Documents.get_documents_by_ref_id(lead_record.id) do
        [] ->
          Logger.info("No existing documents found for lead #{lead_record.id}")

          # get company
          domain =
            case Companies.get_by_id(lead_record.ref_id) do
              {:ok, company} ->
                Logger.info("Company found: #{company.primary_domain}")
                company.primary_domain

              {:error, reason} ->
                Logger.error("Company not found: #{reason}")
                nil
            end

          if domain do
            case BriefWriter.create_brief(
                   lead_record.tenant_id,
                   lead_record.id,
                   domain
                 ) do
              {:ok, _document} ->
                Logger.info("Document created for lead #{lead_record.id}")

              {:error, reason} ->
                Logger.error("Document creation failed: #{inspect(reason)}",
                  lead_id: lead_record.id,
                  url: domain,
                  tenant_id: lead_record.tenant_id
                )
            end
          end

        documents ->
          Logger.info(
            "Found #{length(documents)} existing document(s) for lead #{lead_record.ref_id}"
          )

          Logger.info("Skipping document creation as document(s) already exist")
      end
    end
  end

  def get_icp_fits_without_brief_docs(limit \\ 10) do
    thirty_minutes_ago = DateTime.add(DateTime.utc_now(), -30 * 60)

    Lead
    |> where([l], l.inserted_at < ^thirty_minutes_ago)
    |> where([l], l.stage not in [:pending, :customer])
    |> where([l], not is_nil(l.stage))
    |> where([l], l.icp_fit in [:strong, :moderate])
    |> join(:left, [l], rd in "refs_documents", on: rd.ref_id == l.id)
    |> where([l, rd], is_nil(rd.ref_id))
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> then(fn
      [] -> {:error, :not_found}
      leads -> {:ok, leads}
    end)
  end
end

# Run the script
BriefCreator.run_all(5)
