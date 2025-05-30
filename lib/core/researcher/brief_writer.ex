defmodule Core.Researcher.BriefWriter do
  alias Core.Ai
  alias Core.Crm.Leads
  alias Core.Researcher.IcpProfiles
  alias Core.Crm.Documents
  alias Core.Researcher.ScrapedWebpages
  alias Core.Researcher.BriefWriter.PromptBuilder

  @timeout 60 * 1000

  def start(tenant_id, lead_id, lead_domain) do
    Task.Supervisor.start_child(
      Core.TaskSupervisor,
      fn ->
        create_brief(tenant_id, lead_id, lead_domain)
      end
    )
  end

  def create_brief(tenant_id, lead_id, lead_domain) do
    with {:ok, icp} <- IcpProfiles.get_by_tenant_id(tenant_id),
         {:ok, lead} <- Leads.get_by_id(tenant_id, lead_id),
         {:ok, pages} <-
           ScrapedWebpages.get_business_pages_by_domain(lead_domain, limit: 10),
         request <- build_request(lead_domain, icp, pages),
         {:ok, brief} <-
           generate_brief(request) do
      save_document(lead, brief)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_request(domain, icp, buisenss_pages) do
    {system_prompt, prompt} =
      PromptBuilder.build_prompts(domain, buisenss_pages, icp)

    PromptBuilder.build_request(system_prompt, prompt)
  end

  defp generate_brief(request) do
    task = Ai.ask_supervised(request)

    case Task.yield(task, @timeout) do
      {:ok, {:ok, answer}} ->
        {:ok, answer}

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:exit, reason} ->
        {:error, reason}

      nil ->
        Task.shutdown(task)
        {:error, :timeout}
    end
  end

  defp save_document(lead, brief) do
    doc =
      Documents.Document.new_account_brief(
        lead.tenant_id,
        lead.id,
        brief
      )

    Documents.create_document(doc)
  end
end
