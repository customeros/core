defmodule Core.Researcher.IcpFitEvaluator do
  @moduledoc """
  Evaluates leads against Ideal Customer Profiles (ICPs).

  This module manages:
  * ICP fit evaluation for leads
  * Website content analysis
  * Lead stage updates based on fit
  * Parallel processing of evaluations
  * Retry logic for failed evaluations

  It coordinates the evaluation of leads against tenant-specific
  ICPs, using website content analysis and AI-powered evaluation
  to determine if a lead is a strong fit, moderate fit, or not
  a fit. The module updates lead stages accordingly and handles
  the entire evaluation process asynchronously.
  """

  alias Core.Ai
  alias Core.Researcher.IcpFitEvaluator.PromptBuilder
  alias Core.Researcher.IcpFitEvaluator.Validator
  alias Core.Researcher.Crawler
  alias Core.Researcher.IcpProfiles
  alias Core.Researcher.Webpages
  alias Core.Utils.PrimaryDomainFinder
  alias Core.Crm.Leads

  # 5 mins
  @crawl_timeout 5 * 60 * 1000
  # 45 seconds
  @icp_timeout 45 * 1000
  @max_retries 1

  def evaluate(domain, %Leads.Lead{} = lead)
      when is_binary(domain) and byte_size(domain) > 0 do
    case PrimaryDomainFinder.get_primary_domain(domain) do
      {:ok, primary_domain} -> evaluate_icp_fit(primary_domain, lead)
      {:error, reason} -> {:error, reason}
    end
  end

  def evaluate(domain, _lead) when not is_binary(domain) do
    {:error, "Domain must be a string, got: #{inspect(domain)}"}
  end

  def evaluate(_domain, invalid_lead) do
    {:error, "Expected Lead struct, got: #{inspect(invalid_lead)}"}
  end

  defp evaluate_icp_fit(domain, %Leads.Lead{} = lead) do
    with {:ok, icp} <- IcpProfiles.get_by_tenant_id(lead.tenant_id),
         {:ok, pages} <- get_prompt_context(domain),
         {:ok, fit} <-
           get_icp_fit_with_retry(domain, pages, icp) do
      update_lead(lead, fit)
      {:ok, fit}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_lead(%Leads.Lead{} = lead, fit)
       when fit in [:strong, :moderate, :not_a_fit] do
    case fit do
      :strong ->
        Leads.update_lead(lead, %{icp_fit: :strong, stage: :education})

      :moderate ->
        Leads.update_lead(lead, %{icp_fit: :moderate, stage: :education})

      :not_a_fit ->
        Leads.update_lead(lead, %{stage: :not_a_fit})
    end
  end

  defp crawl_website_with_retry(domain, attempts \\ 0) do
    task = Crawler.crawl_supervised(domain)

    case await_task(task, @crawl_timeout) do
      {:ok, _response} ->
        :ok

      {:error, _reason} when attempts < @max_retries ->
        :timer.sleep(:timer.seconds(attempts + 1))
        crawl_website_with_retry(domain, attempts + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_prompt_context(domain) do
    with :ok <- crawl_website_with_retry(domain),
         {:ok, pages} <-
           Webpages.get_business_pages_by_domain(domain, limit: 8) do
      {:ok, pages}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_icp_fit_with_retry(
         domain,
         [%Webpages.ScrapedWebpage{} | _] = pages,
         %IcpProfiles.Profile{} = icp,
         attempts \\ 0
       ) do
    {system_prompt, prompt} =
      PromptBuilder.build_prompts(domain, pages, icp)

    task = Ai.ask_supervised(PromptBuilder.build_request(system_prompt, prompt))

    case await_task(task, @icp_timeout) do
      {:ok, answer} ->
        case Validator.validate_and_parse(answer) do
          {:ok, fit} -> {:ok, fit}
          {:error, reason} -> {:error, reason}
        end

      {:error, _reason} when attempts < @max_retries ->
        :timer.sleep(:timer.seconds(attempts + 1))
        get_icp_fit_with_retry(domain, pages, icp, attempts + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp await_task(task, timeout) do
    case Task.yield(task, timeout) do
      {:ok, {:ok, response}} -> {:ok, response}
      {:ok, {:error, reason}} -> {:error, reason}
      {:exit, reason} -> {:error, reason}
      nil -> {:error, :timeout}
    end
  end
end
