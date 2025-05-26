defmodule Core.Researcher.IcpFitEvaluator do
  alias Core.Ai.AskAi
  alias Core.Researcher.IcpFitEvaluator.PromptBuilder
  alias Core.Researcher.IcpFitEvaluator.Validator
  alias Core.Researcher.Crawler
  alias Core.Researcher.IcpProfiles
  alias Core.Researcher.ScrapedWebpages

  # 2 mins
  @icp_fit_timeout 2 * 60 * 1000

  def evaluate(tenant_id, domain) do
    with {:ok, icp} <- IcpProfiles.get_by_tenant_id(tenant_id),
         {:ok, _scraped_data} <-
           Crawler.start_sync(domain),
         {:ok, pages} <-
           ScrapedWebpages.get_business_pages_by_domain(domain,
             limit: 10
           ),
         {:ok, fit} <- get_icp_fit(domain, pages, icp) do
      {:ok, fit}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_icp_fit(domain, pages, icp) do
    task =
      Task.Supervisor.async(
        Core.Researcher.IcpFitEvaluator.Supervisor,
        fn ->
          {system_prompt, prompt} =
            PromptBuilder.build_prompts(domain, pages, icp)

          with {:ok, answer} <-
                 AskAi.ask_with_timeout(
                   PromptBuilder.build_request(system_prompt, prompt)
                 ),
               {:ok, fit} <- Validator.validate_and_parse(answer) do
            {:ok, fit}
          else
            {:error, reason} -> {:error, reason}
          end
        end
      )

    case Task.yield(task, @icp_fit_timeout) do
      {:ok, result} ->
        result

      nil ->
        Task.Supervisor.terminate_child(MyApp.TaskSupervisor, task.pid)
        {:error, :ai_timeout}

      {:exit, reason} ->
        {:error, {:ai_failed, reason}}
    end
  end
end
