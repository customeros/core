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

  require OpenTelemetry.Tracer

  alias Core.Ai
  alias Core.Crm.Leads
  alias Core.Utils.Tracing
  alias Core.Utils.TaskAwaiter
  alias Core.Researcher.Crawler
  alias Core.Researcher.Webpages
  alias Core.Researcher.IcpProfiles
  alias Core.Utils.PrimaryDomainFinder
  alias Core.Researcher.IcpFitEvaluator.Validator
  alias Core.Researcher.IcpFitEvaluator.PromptBuilder

  # 5 mins
  @crawl_timeout 5 * 60 * 1000
  # 45 seconds
  @icp_timeout 45 * 1000
  @max_retries 1

  def evaluate(domain, lead, opts \\ [])

  def evaluate(domain, %Leads.Lead{} = lead, opts)
      when is_binary(domain) and byte_size(domain) > 0 do
    OpenTelemetry.Tracer.with_span "icp_fit_evaluator.evaluate" do
      case PrimaryDomainFinder.get_primary_domain(domain) do
        {:ok, primary_domain} ->
          evaluate_icp_fit_and_update_lead(primary_domain, lead, opts)

        {:error, reason} ->
          Tracing.error(reason)
          {:error, reason}
      end
    end
  end

  def evaluate(domain, _lead, _opts) when not is_binary(domain) do
    {:error, "Domain must be a string, got: #{inspect(domain)}"}
  end

  def evaluate(_domain, invalid_lead, _opts) do
    {:error, "Expected Lead struct, got: #{inspect(invalid_lead)}"}
  end

  defp evaluate_icp_fit_and_update_lead(domain, %Leads.Lead{} = lead, opts) do
    OpenTelemetry.Tracer.with_span "icp_fit_evaluator.evaluate_icp_fit_and_update_lead" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.lead.id", lead.id},
        {"param.tenant.id", lead.tenant_id},
        {"param.domain", domain}
      ])

      with {:ok, icp} <- IcpProfiles.get_by_tenant_id(lead.tenant_id),
           {:ok, pages} <- get_prompt_context(domain, opts),
           {:ok, evaluation} <-
             get_icp_fit_with_retry(domain, pages, icp, 0) do
        update_lead(lead, evaluation)
        {:ok, evaluation}
      else
        {:error, :no_business_pages_found} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.icp_fit", :not_a_fit},
            {"result.reason", :no_business_pages_found}
          ])

          evaluation = %{
            icp_fit: :not_a_fit,
            icp_disqualification_reason: [:no_business_pages_found]
          }

          update_lead(lead, evaluation)
          {:ok, evaluation}

        {:error, reason} ->
          Tracing.error(reason)
          {:error, reason}
      end
    end
  end

  defp update_lead(%Leads.Lead{} = lead, %{
         icp_fit: fit,
         icp_disqualification_reason: reasons
       }) do
    OpenTelemetry.Tracer.with_span "icp_fit_evaluator.update_lead" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.lead.id", lead.id},
        {"param.icp_fit", fit},
        {"param.icp_disqualification_reason", reasons}
      ])

      update_attrs = %{
        icp_fit: fit,
        icp_disqualification_reason: reasons
      }

      stage_attrs =
        case fit do
          :strong ->
            %{stage: :target}

          :moderate ->
            %{stage: :target}

          :not_a_fit ->
            %{stage: nil}
        end

      Leads.update_lead(lead, Map.merge(update_attrs, stage_attrs))
    end
  end

  defp crawl_website_with_retry(domain, opts, attempts) do
    OpenTelemetry.Tracer.with_span "icp_fit_evaluator.crawl_website_with_retry" do
      task = Crawler.crawl_supervised(domain, opts)

      case TaskAwaiter.await(task, @crawl_timeout) do
        {:ok, _response} ->
          :ok

        {:error, _reason} when attempts < @max_retries ->
          :timer.sleep(:timer.seconds(attempts + 1))
          crawl_website_with_retry(domain, opts, attempts + 1)

        {:error, reason} ->
          Tracing.error(reason)
          {:error, reason}
      end
    end
  end

  defp get_prompt_context(domain, opts) do
    OpenTelemetry.Tracer.with_span "icp_fit_evaluator.get_prompt_context" do
      with :ok <- crawl_website_with_retry(domain, opts, 0),
           {:ok, pages} <-
             Webpages.get_business_pages_by_domain(domain, limit: 8) do
        {:ok, pages}
      else
        {:error, :no_business_pages_found} ->
          {:error, :no_business_pages_found}

        {:error, reason} ->
          Tracing.error(reason)
          {:error, reason}
      end
    end
  end

  defp get_icp_fit_with_retry(
         domain,
         [%Webpages.ScrapedWebpage{} | _] = pages,
         %IcpProfiles.Profile{} = icp,
         attempts
       ) do
    OpenTelemetry.Tracer.with_span "icp_fit_evaluator.get_icp_fit_with_retry" do
      OpenTelemetry.Tracer.set_attributes([
        {"domain", domain},
        {"attempt", attempts}
      ])

      {system_prompt, prompt} =
        PromptBuilder.build_prompts(domain, pages, icp)

      task =
        Ai.ask_supervised(PromptBuilder.build_request(system_prompt, prompt))

      case TaskAwaiter.await(task, @icp_timeout) do
        {:ok, answer} ->
          case Validator.validate_and_parse(answer) do
            {:ok, evaluation} ->
              {:ok, evaluation}

            {:error, reason} ->
              Tracing.error(reason)
              {:error, reason}
          end

        {:error, _reason} when attempts < @max_retries ->
          :timer.sleep(:timer.seconds(attempts + 1))
          get_icp_fit_with_retry(domain, pages, icp, attempts + 1)

        {:error, reason} ->
          Tracing.error(reason)
          {:error, reason}
      end
    end
  end
end
