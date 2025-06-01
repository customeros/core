defmodule Core.Researcher.IcpFitEvaluator do
  alias Core.Ai
  alias Core.Researcher.IcpFitEvaluator.PromptBuilder
  alias Core.Researcher.IcpFitEvaluator.Validator
  alias Core.Researcher.Crawler
  alias Core.Researcher.IcpProfiles
  alias Core.Researcher.ScrapedWebpages
  alias Core.Utils.PrimaryDomainFinder
  alias Core.Crm.Leads

  # 5 mins
  @icp_fit_timeout 5 * 60 * 1000

  def evaluate_start(domain, lead) do
    Task.Supervisor.start_child(
      Core.TaskSupervisor,
      fn ->
        evaluate(domain, lead)
      end
    )
  end

  def evaluate(domain, lead) do
    with {:ok, primary_domain} <-
           PrimaryDomainFinder.get_primary_domain(domain),
         {:ok, icp} <- IcpProfiles.get_by_tenant_id(lead.tenant_id),
         {:ok, pages} <- get_prompt_context(primary_domain),
         {:ok, fit} <-
           get_icp_fit(primary_domain, pages, icp) do
      update_lead(lead, fit)
      {:ok, fit}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_lead(lead, fit) do
    case fit do
      :strong ->
        Leads.update_lead(lead, %{icp_fit: :strong, stage: :education})

      :moderate ->
        Leads.update_lead(lead, %{icp_fit: :moderate, stage: :education})

      :not_a_fit ->
        Leads.update_lead(lead, %{stage: :not_a_fit})
    end
  end

  defp get_prompt_context(domain) do
    task = Crawler.crawl_supervised(domain)

    case Task.yield(task, @icp_fit_timeout) do
      {:ok, {:ok, _result}} ->
        case(
          ScrapedWebpages.get_business_pages_by_domain(domain,
            limit: 8
          )
        ) do
          {:ok, pages} ->
            {:ok, pages}

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:exit, reason} ->
        {:exit, reason}

      nil ->
        Task.shutdown(task)
        {:error, :icp_timeout}
    end
  end

  defp get_icp_fit(domain, pages, icp) do
    {system_prompt, prompt} =
      PromptBuilder.build_prompts(domain, pages, icp)

    task = Ai.ask_supervised(PromptBuilder.build_request(system_prompt, prompt))

    case Task.yield(task, @icp_fit_timeout) do
      {:ok, {:ok, answer}} ->
        case Validator.validate_and_parse(answer) do
          {:ok, fit} -> {:ok, fit}
          {:error, reason} -> {:error, reason}
        end

      {:ok, {:error, reason}} ->
        {:error, reason}

      nil ->
        Task.shutdown(task)
        {:error, :ai_timeout}

      {:exit, reason} ->
        {:error, reason}
    end
  end
end
