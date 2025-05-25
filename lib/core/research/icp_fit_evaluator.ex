defmodule Core.Research.IcpFitEvaluator do
  alias Core.Ai.AskAi
  alias Core.Research.IcpFitEvaluator.PromptBuilder
  alias Core.Research.IcpFitEvaluator.Validator

  def evaluate(tenant_id, domain) do
    with {:ok, icp} <- Core.Research.IcpProfiles.get_by_tenant_id(tenant_id),
         {:ok, _scraped_data} <-
           Core.Research.Crawler.start(domain),
         {:ok, pages} <-
           Core.Research.ScrapedWebpages.get_business_pages_by_domain(domain,
             limit: 10
           ),
         {:ok, fit} <- get_icp_fit(domain, pages, icp) do
      {:ok, fit}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_icp_fit(domain, pages, icp) do
    {system_prompt, prompt} = PromptBuilder.build_prompts(domain, pages, icp)

    with {:ok, answer} <-
           AskAi.ask(PromptBuilder.build_request(system_prompt, prompt)),
         {:ok, fit} <-
           Validator.validate_and_parse(answer) do
      {:ok, fit}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
