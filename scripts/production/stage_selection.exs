Application.ensure_all_started(:core)

defmodule StageSelector do
  alias Core.Crm.Leads
  alias Core.Auth.Tenants
  alias Core.WebTracker.Sessions
  alias Core.WebTracker.SessionAnalyzer

  def run_all() do
    IO.puts("Getting ICP fits without an evaluated stage...")

    case Leads.get_icp_fits_without_stage() do
      {:error, :not_found} -> 
        IO.puts("No leads to evaluate.")
        
      {:ok, leads} ->
        IO.puts("Processing #{length(leads)} leads...")
        
        leads
        |> Enum.with_index(1)
        |> Enum.each(fn {lead, index} ->
          IO.puts("[#{index}/#{length(leads)}] Processing lead: #{lead.ref_id}")
          process_lead(lead)
        end)
        
        IO.puts("Completed processing all leads.")
    end
  end

  def run(lead_id, tenant_id) do
    case Leads.get_by_id(tenant_id, lead_id) do
      {:ok, lead} -> process_lead(lead)
      {:error, reason} -> IO.puts("Unable to process lead: #{reason}")
    end
  end

  defp process_lead(lead_record) do
    with {:ok, tenant} <- Tenants.get_tenant_by_id(lead_record.tenant_id),
         {:ok, sessions} <- Sessions.get_all_closed_sessions_by_tenant_and_company(tenant.name, lead_record.ref_id) do
      
      IO.puts("  Found #{length(sessions)} sessions for lead #{lead_record.ref_id}")
      
      Enum.each(sessions, fn session ->
        IO.puts("    Starting analysis for session: #{session.id}")
        SessionAnalyzer.analyze_session(session.id)
      end)
    else
      {:error, :not_found} -> 
        IO.puts("  ✗ Tenant #{lead_record.tenant_id} or Sessions not found for lead #{lead_record.ref_id}")
        # Set to target when no sessions found
        Leads.update_lead(lead_record, %{stage: :target})
        
      {:error, reason} ->
        IO.puts("  ✗ Error processing lead #{lead_record.ref_id}: #{inspect(reason)}")
    end
  end
end

StageSelector.run_all()
