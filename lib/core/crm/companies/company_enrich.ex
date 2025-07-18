defmodule Core.Crm.Companies.CompanyEnrich do
  @moduledoc """
  Manages company data enrichment and enrichment tasks.

  This module manages:
  * Company homepage scraping
  * Industry classification
  * Company name extraction
  * Country identification
  * Company icon processing
  * Enrichment task coordination
  * Error handling and retries

  It coordinates various enrichment tasks to gather and process
  company information from multiple sources. The module handles
  asynchronous processing of enrichment tasks, including website
  scraping, AI-powered analysis, and data updates, with proper
  error handling and retry mechanisms.
  """

  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query
  alias Core.Repo
  alias Core.Crm.Companies.Company
  alias Core.Crm.Companies.Enrichment
  alias Core.Crm.Industries
  alias Core.Utils.Media.Images
  alias Core.Utils.Tracing
  alias Core.Researcher.Scraper

  @err_not_found {:error, "not found"}
  @err_update_failed {:error, "update failed"}
  @err_invalid_request {:error, "invalid request"}
  @err_image_not_found {:error, :image_not_found}
  @err_timeout {:error, "fetch image timed out"}
  @err_empty_ai_response {:error, "empty ai response"}
  @err_scrape_not_needed {:error, "scrape not needed"}
  @err_industry_not_found {:error, :industry_not_found}
  @err_invalid_homepage {:error, "homepage content invalid"}
  @err_enrichment_not_needed {:error, "enrichment not needed"}

  @spec scrape_homepage_start(String.t()) :: {:ok, pid()} | {:error, term()}
  def scrape_homepage_start(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.scrape_homepage_task" do
      current_ctx = OpenTelemetry.Ctx.get_current()

      Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
        OpenTelemetry.Ctx.attach(current_ctx)
        scrape_homepage(company_id)
      end)
    end
  end

  def scrape_homepage(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.scrape_homepage" do
      with {:ok, company} <- fetch_company(company_id),
           :ok <- validate_scrape_eligibility(company),
           :ok <- mark_scrape_attempt(company_id),
           {:ok, _content} <- scrape_company_homepage(company),
           :ok <- set_homepage_scraped(company_id) do
        trigger_enrichment_tasks(company_id)
        :ok
      else
        {:error, reason} -> handle_scrape_error(company_id, reason)
      end
    end
  end

  defp fetch_company(company_id) do
    case Repo.get(Company, company_id) do
      nil ->
        Tracing.error(:not_found, "Company not found", company_id: company_id)
        @err_not_found

      company ->
        {:ok, company}
    end
  end

  defp validate_scrape_eligibility(company) do
    if should_scrape_homepage?(company) do
      :ok
    else
      @err_scrape_not_needed
    end
  end

  defp mark_scrape_attempt(company_id) do
    now = DateTime.utc_now()

    case Repo.update_all(
           from(c in Company, where: c.id == ^company_id),
           set: [domain_scrape_attempt_at: now],
           inc: [domain_scrape_attempts: 1]
         ) do
      {0, _} ->
        Tracing.error(
          :update_failed,
          "Failed to mark scrape attempt for company",
          company_id: company_id
        )

        @err_update_failed

      {_count, _} ->
        :ok
    end
  end

  defp scrape_company_homepage(company) do
    OpenTelemetry.Tracer.with_span "company_enrich.scrape_company_homepage" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      case Scraper.scrape_webpage(company.primary_domain) do
        {:ok, %{content: content}} when is_binary(content) ->
          {:ok, content}

        {:error, :no_content} ->
          Tracing.warning(
            :no_content,
            "No valid content available by url content type",
            company_id: company.id,
            company_domain: company.primary_domain
          )

          @err_invalid_homepage

        {:error, :timeout} ->
          Tracing.warning(
            :timeout,
            "URL validation timed out",
            company_id: company.id,
            company_domain: company.primary_domain
          )

          @err_invalid_homepage

        {:error, :unprocessable} ->
          Tracing.warning(
            :unprocessable,
            "Content is unprocessable, url: #{company.primary_domain}"
          )

          @err_invalid_homepage

        {:error, :not_primary_domain} ->
          Tracing.warning(
            :not_primary_domain,
            "Not primary domain, url: #{company.primary_domain}"
          )

          @err_invalid_homepage

        {:error, reason} ->
          Tracing.error(reason, "Failed to scrape homepage for company",
            company_id: company.id,
            company_domain: company.primary_domain
          )

          {:error, reason}
      end
    end
  end

  defp set_homepage_scraped(company_id) do
    case Repo.update_all(
           from(c in Company, where: c.id == ^company_id),
           set: [homepage_scraped: true]
         ) do
      {0, _} ->
        Tracing.error(:update_failed, "Failed to update homepage for company",
          company_id: company_id
        )

        @err_update_failed

      {_count, _} ->
        :ok
    end
  end

  defp trigger_enrichment_tasks(company_id) do
    [
      enrich_icon_task(company_id),
      enrich_name_task(company_id),
      enrich_industry_task(company_id),
      enrich_country_task(company_id),
      enrich_business_model_task(company_id)
    ]
    |> Enum.each(fn
      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to start enrichment task: #{inspect(reason)}")
    end)
  end

  defp handle_scrape_error(company_id, :scrape_not_needed) do
    Logger.debug(
      "Skipping homepage scrape for company #{company_id} - not needed"
    )

    :ok
  end

  defp handle_scrape_error(_company_id, reason) do
    {:error, reason}
  end

  @spec enrich_industry_task(String.t()) :: {:ok, pid()} | {:error, term()}
  def enrich_industry_task(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_industry_task" do
      current_ctx = OpenTelemetry.Ctx.get_current()

      Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
        OpenTelemetry.Ctx.attach(current_ctx)
        enrich_industry(company_id)
      end)
    end
  end

  def enrich_industry(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_industry" do
      OpenTelemetry.Tracer.set_attributes([{"company.id", company_id}])

      with {:ok, company} <-
             fetch_company_for_enrichment(company_id, "industry"),
           :ok <- validate_industry_eligibility(company),
           :ok <- mark_industry_attempt(company_id),
           {:ok, industry_code} <- get_industry_code_from_ai(company),
           {:ok, industry} <- lookup_industry(industry_code, company),
           :ok <- update_company_industry(company_id, industry) do
        :ok
      else
        {:error, reason} ->
          handle_enrichment_error(company_id, reason, "industry")
      end
    end
  end

  defp validate_industry_eligibility(company) do
    if should_enrich_industry?(company),
      do: :ok,
      else: @err_enrichment_not_needed
  end

  defp mark_industry_attempt(company_id) do
    case Repo.update_all(
           from(c in Company, where: c.id == ^company_id),
           set: [industry_enrich_attempt_at: DateTime.utc_now()],
           inc: [industry_enrichment_attempts: 1]
         ) do
      {0, _} ->
        Tracing.error(
          :update_failed,
          "Failed to mark industry enrichment attempt for company",
          company_id: company_id
        )

        @err_update_failed

      {_count, _} ->
        :ok
    end
  end

  defp get_industry_code_from_ai(company) do
    case get_homepage_content(company.primary_domain) do
      {:ok, homepage_content} ->
        case Enrichment.Industry.identify(%{
               domain: company.primary_domain,
               homepage_content: homepage_content
             }) do
          {:ok, industry_code} ->
            OpenTelemetry.Tracer.set_attributes([
              {"ai.industry.code", industry_code}
            ])

            {:ok, industry_code}

          {:error, {:invalid_request, reason}} ->
            Tracing.error(
              :invalid_request,
              "Invalid ai request for industry enrichment: #{inspect(reason)}",
              company_id: company.id
            )

            @err_invalid_request

          {:error, :empty_ai_response} ->
            Tracing.warning(:empty_ai_response, "No industry code from AI",
              company_id: company.id
            )

            @err_empty_ai_response

          {:error, :max_attempts_exceeded} ->
            Tracing.warning(
              :max_attempts_exceeded,
              "Max attempts exceeded for industry enrichment",
              company_id: company.id
            )

            @err_industry_not_found

          {:error, reason} ->
            Tracing.error(reason, "Failed to get industry NAICS code from AI",
              company_id: company.id,
              company_domain: company.primary_domain
            )

            {:error, reason}
        end

      {:error, reason} ->
        Tracing.error(reason)
        {:error, reason}
    end
  end

  defp lookup_industry(industry_code, company) do
    case Industries.get_by_code(industry_code) do
      nil ->
        Tracing.error(
          :industry_not_found,
          "Industry code #{industry_code} not available in db",
          company_domain: company.primary_domain,
          company_id: company.id
        )

        @err_industry_not_found

      industry ->
        {:ok, industry}
    end
  end

  defp update_company_industry(company_id, industry) do
    case Repo.update_all(
           from(c in Company, where: c.id == ^company_id),
           set: [industry_code: industry.code, industry: industry.name]
         ) do
      {0, _} ->
        Tracing.error(:update_failed, "Failed to update industry for company",
          company_id: company_id
        )

        @err_update_failed

      {_count, _} ->
        :ok
    end
  end

  @spec enrich_name_task(String.t()) :: {:ok, pid()} | {:error, term()}
  def enrich_name_task(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_name_task" do
      current_ctx = OpenTelemetry.Ctx.get_current()

      Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
        OpenTelemetry.Ctx.attach(current_ctx)
        enrich_name(company_id)
      end)
    end
  end

  def enrich_name(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_name" do
      OpenTelemetry.Tracer.set_attributes([{"company.id", company_id}])

      with {:ok, company} <- fetch_company_for_enrichment(company_id, "name"),
           :ok <- validate_name_eligibility(company),
           :ok <- mark_name_attempt(company_id),
           {:ok, name} <- get_name_from_ai(company),
           :ok <- update_company_name(company_id, name) do
        :ok
      else
        {:error, reason} -> handle_enrichment_error(company_id, reason, "name")
      end
    end
  end

  defp validate_name_eligibility(company) do
    if should_enrich_name?(company),
      do: :ok,
      else: @err_enrichment_not_needed
  end

  defp mark_name_attempt(company_id) do
    case Repo.update_all(
           from(c in Company, where: c.id == ^company_id),
           set: [name_enrich_attempt_at: DateTime.utc_now()],
           inc: [name_enrichment_attempts: 1]
         ) do
      {0, _} ->
        Tracing.error(
          :update_failed,
          "Failed to mark name enrichment attempt for company",
          company_id: company_id
        )

        @err_update_failed

      {_count, _} ->
        :ok
    end
  end

  defp get_name_from_ai(company) do
    case get_homepage_content(company.primary_domain) do
      {:ok, homepage_content} ->
        case Enrichment.Name.identify(%{
               domain: company.primary_domain,
               homepage_content: homepage_content
             }) do
          {:ok, name} ->
            OpenTelemetry.Tracer.set_attributes([{"ai.name", name}])
            {:ok, name}

          {:error, reason, name} when is_binary(name) and name != "" ->
            Tracing.error(reason, "Rejected company name from AI",
              company_id: company.id,
              company_domain: company.primary_domain,
              name: name
            )

            {:error, reason}

          {:error, reason, _} ->
            Tracing.error(reason, "AI name identification failed",
              company_id: company.id,
              company_domain: company.primary_domain
            )

            {:error, reason}

          {:error, :name_empty} ->
            Tracing.warning(:name_empty, "No name from AI")

            @err_empty_ai_response

          {:error, reason} ->
            Tracing.error(reason, "Failed to get name from AI for company",
              company_id: company.id,
              company_domain: company.primary_domain
            )

            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_company_name(company_id, name) do
    case Repo.update_all(
           from(c in Company, where: c.id == ^company_id),
           set: [name: name]
         ) do
      {0, _} ->
        Tracing.error(:update_failed, "Failed to update name for company",
          company_id: company_id
        )

        @err_update_failed

      {_count, _} ->
        :ok
    end
  end

  @spec enrich_country_task(String.t()) :: {:ok, pid()} | {:error, term()}
  def enrich_country_task(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_country_task" do
      current_ctx = OpenTelemetry.Ctx.get_current()

      Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
        OpenTelemetry.Ctx.attach(current_ctx)
        enrich_country(company_id)
      end)
    end
  end

  def enrich_country(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_country" do
      OpenTelemetry.Tracer.set_attributes([{"company.id", company_id}])

      with {:ok, company} <-
             fetch_company_for_enrichment(company_id, "country"),
           :ok <- validate_country_eligibility(company),
           :ok <- mark_country_attempt(company_id),
           {:ok, country_code} <- get_country_from_ai(company),
           :ok <- update_company_country(company_id, country_code) do
        :ok
      else
        {:error, reason} ->
          handle_enrichment_error(company_id, reason, "country")
      end
    end
  end

  defp validate_country_eligibility(company) do
    if should_enrich_country?(company),
      do: :ok,
      else: @err_enrichment_not_needed
  end

  defp mark_country_attempt(company_id) do
    case Repo.update_all(
           from(c in Company, where: c.id == ^company_id),
           set: [country_enrich_attempt_at: DateTime.utc_now()],
           inc: [country_enrichment_attempts: 1]
         ) do
      {0, _} ->
        Tracing.error(
          :update_failed,
          "Failed to mark country enrichment attempt for company",
          company_id: company_id
        )

        @err_update_failed

      {_count, _} ->
        :ok
    end
  end

  defp get_country_from_ai(company) do
    case get_homepage_content(company.primary_domain) do
      {:ok, homepage_content} ->
        case Enrichment.Location.identify_country_code_a2(%{
               domain: company.primary_domain,
               homepage_content: homepage_content
             }) do
          {:ok, "XX"} ->
            OpenTelemetry.Tracer.set_attributes([{"ai.country_code_a2", "XX"}])
            {:ok, :skip_update}

          {:ok, country_code_a2} ->
            OpenTelemetry.Tracer.set_attributes([
              {"ai.country_code_a2", country_code_a2}
            ])

            {:ok, String.upcase(country_code_a2)}

          {:error, reason} ->
            Tracing.error(
              reason,
              "Failed to get country code from AI for company",
              company_id: company.id
            )

            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_company_country(_company_id, :skip_update), do: :ok

  defp update_company_country(company_id, country_code) do
    case Repo.update_all(
           from(c in Company, where: c.id == ^company_id),
           set: [country_a2: country_code]
         ) do
      {0, _} ->
        Tracing.error(
          :update_failed,
          "Failed to update country code for company",
          company_id: company_id
        )

        @err_update_failed

      {_count, _} ->
        :ok
    end
  end

  @spec enrich_icon_task(String.t()) :: {:ok, pid()} | {:error, term()}
  def enrich_icon_task(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_icon_task" do
      current_ctx = OpenTelemetry.Ctx.get_current()

      Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
        OpenTelemetry.Ctx.attach(current_ctx)
        enrich_icon(company_id)
      end)
    end
  end

  def enrich_icon(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_icon" do
      OpenTelemetry.Tracer.set_attributes([{"company.id", company_id}])

      with {:ok, company} <- fetch_company_for_enrichment(company_id, "icon"),
           :ok <- validate_icon_eligibility(company),
           :ok <- mark_icon_attempt(company_id),
           {:ok, image_data} <- download_company_icon(company),
           {:ok, storage_key} <- store_company_icon(image_data, company_id),
           :ok <- update_company_icon(company_id, storage_key) do
        :ok
      else
        {:error, reason} -> handle_enrichment_error(company_id, reason, "icon")
      end
    end
  end

  defp validate_icon_eligibility(company) do
    if should_enrich_icon?(company),
      do: :ok,
      else: @err_enrichment_not_needed
  end

  defp mark_icon_attempt(company_id) do
    case Repo.update_all(
           from(c in Company, where: c.id == ^company_id),
           set: [icon_enrich_attempt_at: DateTime.utc_now()],
           inc: [icon_enrichment_attempts: 1]
         ) do
      {0, _} ->
        Tracing.error(
          :update_failed,
          "Failed to mark icon enrichment attempt for company",
          company_id: company_id
        )

        @err_update_failed

      {_count, _} ->
        :ok
    end
  end

  defp download_company_icon(%Company{} = company) do
    brandfetch_client_id =
      Application.get_env(:core, :brandfetch)[:client_id] ||
        raise "BRANDFETCH_CLIENT_ID is not configured"

    brandfetch_url =
      "https://cdn.brandfetch.io/#{company.primary_domain}/fallback/404/w/400?c=#{brandfetch_client_id}"

    case Images.download_image(brandfetch_url) do
      {:ok, image_data} ->
        {:ok, image_data}

      {:error, :image_not_found} ->
        Tracing.warning(
          :image_not_found,
          "Icon not found for company #{company.id} (domain: #{company.primary_domain})"
        )

        @err_image_not_found

      {:error, :timeout} ->
        Tracing.warning(:timeout, "Fetching company icon timed out")

        if company.icon_enrichment_attempts >= 2 do
          download_company_logo(company)
        else
          @err_timeout
        end

      {:error, "HTTP request failed with status 500"} ->
        Tracing.warning(:http_error, "HTTP request failed with status 500")

        if company.icon_enrichment_attempts >= 2 do
          download_company_logo(company)
        else
          @err_image_not_found
        end

      {:error, "HTTP request failed with status 429"} ->
        Tracing.warning(
          :rate_limited,
          "Icon download rate limited, will retry later",
          company_id: company.id,
          company_domain: company.primary_domain
        )

        # Return a retryable error for rate limiting
        {:error, :rate_limited}

      {:error, reason} ->
        Tracing.error(reason, "Failed to download icon for company",
          company_id: company.id,
          company_domain: company.primary_domain
        )

        {:error, reason}
    end
  end

  defp download_company_logo(%Company{} = company) do
    brandfetch_client_id =
      Application.get_env(:core, :brandfetch)[:client_id] ||
        raise "BRANDFETCH_CLIENT_ID is not configured"

    brandfetch_url =
      "https://cdn.brandfetch.io/#{company.primary_domain}/fallback/404/w/400/logo?c=#{brandfetch_client_id}"

    case Images.download_image(brandfetch_url) do
      {:ok, image_data} ->
        {:ok, image_data}

      {:error, :image_not_found} ->
        Tracing.warning(
          :image_not_found,
          "Logo not found for company #{company.id} (domain: #{company.primary_domain})"
        )

        @err_image_not_found

      {:error, :timeout} ->
        Tracing.warning(:timeout, "Fetching company logo timed out")

        @err_timeout

      {:error, reason} ->
        Tracing.error(reason, "Failed to download logo for company",
          company_id: company.id,
          company_domain: company.primary_domain
        )

        {:error, reason}
    end
  end

  defp store_company_icon(image_data, company_id) do
    case Images.store_image(
           image_data,
           "image/jpeg",
           "",
           %{generate_name: true, path: "_companies"}
         ) do
      {:ok, storage_key} ->
        {:ok, storage_key}

      {:error, reason} ->
        Tracing.error(reason, "Failed to store icon for company",
          company_id: company_id
        )

        {:error, reason}
    end
  end

  defp update_company_icon(company_id, storage_key) do
    case Repo.update_all(
           from(c in Company, where: c.id == ^company_id),
           set: [icon_key: storage_key]
         ) do
      {0, _} ->
        Tracing.error(:update_failed, "Failed to update icon key for company",
          company_id: company_id
        )

        @err_update_failed

      {_count, _} ->
        :ok
    end
  end

  # Shared helper functions for enrichment

  defp fetch_company_for_enrichment(company_id, enrichment_type) do
    case Repo.get(Company, company_id) do
      nil ->
        Tracing.error(
          :not_found,
          "Company not found for enrichment #{enrichment_type}",
          company_id: company_id
        )

        @err_not_found

      company ->
        {:ok, company}
    end
  end

  defp handle_enrichment_error(
         company_id,
         :enrichment_not_needed,
         enrichment_type
       ) do
    Logger.debug(
      "Skipping #{enrichment_type} enrichment for company #{company_id} - not needed"
    )

    :ok
  end

  defp handle_enrichment_error(_company_id, reason, _enrichment_type) do
    {:error, reason}
  end

  @spec enrich_business_model_task(String.t()) ::
          {:ok, pid()} | {:error, term()}
  def enrich_business_model_task(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_business_model_task" do
      current_ctx = OpenTelemetry.Ctx.get_current()

      Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
        OpenTelemetry.Ctx.attach(current_ctx)
        enrich_business_model(company_id)
      end)
    end
  end

  def enrich_business_model(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_business_model" do
      OpenTelemetry.Tracer.set_attributes([{"company.id", company_id}])

      with {:ok, company} <-
             fetch_company_for_enrichment(company_id, "business_model"),
           :ok <- validate_business_model_eligibility(company),
           :ok <- mark_business_model_attempt(company_id),
           {:ok, business_model} <- get_business_model_from_ai(company),
           :ok <- update_company_business_model(company_id, business_model) do
        :ok
      else
        {:error, reason} ->
          handle_enrichment_error(company_id, reason, "business_model")
      end
    end
  end

  defp validate_business_model_eligibility(company) do
    if should_enrich_business_model?(company),
      do: :ok,
      else: @err_enrichment_not_needed
  end

  defp mark_business_model_attempt(company_id) do
    case Repo.update_all(
           from(c in Company, where: c.id == ^company_id),
           set: [business_model_enrich_attempt_at: DateTime.utc_now()],
           inc: [business_model_enrichment_attempts: 1]
         ) do
      {0, _} ->
        Tracing.error(
          :update_failed,
          "Failed to mark business model enrichment attempt for company",
          company_id: company_id
        )

        @err_update_failed

      {_count, _} ->
        :ok
    end
  end

  defp get_business_model_from_ai(company) do
    case get_homepage_content(company.primary_domain) do
      {:ok, homepage_content} ->
        case Enrichment.BusinessModel.identify_business_model(
               company.primary_domain,
               homepage_content
             ) do
          {:ok, business_model} -> {:ok, business_model}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_company_business_model(company_id, business_model) do
    case Repo.update_all(
           from(c in Company, where: c.id == ^company_id),
           set: [business_model: business_model]
         ) do
      {0, _} ->
        Tracing.error(
          :update_failed,
          "Failed to update business model for company",
          company_id: company_id
        )

        @err_update_failed

      {_count, _} ->
        :ok
    end
  end

  # Private helper methods
  @spec should_enrich_industry?(Company.t()) :: boolean()
  defp should_enrich_industry?(%Company{} = company) do
    OpenTelemetry.Tracer.with_span "company_enrich.should_enrich_industry?" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      if company.homepage_scraped do
        result = is_nil(company.industry_code) or company.industry_code == ""

        OpenTelemetry.Tracer.set_attributes([
          {"result", result}
        ])

        result
      else
        OpenTelemetry.Tracer.set_attributes([
          {"result", "false"}
        ])

        false
      end
    end
  end

  defp should_enrich_industry?(_), do: false

  @spec should_enrich_name?(Company.t()) :: boolean()
  defp should_enrich_name?(%Company{} = company) do
    OpenTelemetry.Tracer.with_span "company_enrich.should_enrich_name?" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      if company.homepage_scraped do
        result = is_nil(company.name) or company.name == ""

        OpenTelemetry.Tracer.set_attributes([
          {"result", result}
        ])

        result
      else
        OpenTelemetry.Tracer.set_attributes([
          {"result", "false"}
        ])

        false
      end
    end
  end

  defp should_enrich_name?(_), do: false

  @spec should_enrich_country?(Company.t()) :: boolean()
  defp should_enrich_country?(%Company{} = company) do
    OpenTelemetry.Tracer.with_span "company_enrich.should_enrich_country?" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      if company.homepage_scraped do
        result = is_nil(company.country_a2) or company.country_a2 == ""

        OpenTelemetry.Tracer.set_attributes([
          {"result", result}
        ])

        result
      else
        OpenTelemetry.Tracer.set_attributes([
          {"result", "false"}
        ])

        false
      end
    end
  end

  defp should_enrich_country?(_), do: false

  @spec should_enrich_business_model?(Company.t()) :: boolean()
  defp should_enrich_business_model?(%Company{} = company) do
    OpenTelemetry.Tracer.with_span "company_enrich.should_enrich_business_model?" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      case company.homepage_scraped do
        true ->
          result =
            is_nil(company.business_model) or company.business_model == ""

          OpenTelemetry.Tracer.set_attributes([
            {"result", result}
          ])

          result

        false ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", "false"}
          ])

          false
      end
    end
  end

  defp should_enrich_business_model?(_), do: false

  @spec should_enrich_icon?(Company.t()) :: boolean()
  defp should_enrich_icon?(%Company{} = company) do
    OpenTelemetry.Tracer.with_span "company_enrich.should_enrich_icon?" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      result = is_nil(company.icon_key) or company.icon_key == ""

      OpenTelemetry.Tracer.set_attributes([
        {"result", result}
      ])

      result
    end
  end

  defp should_enrich_icon?(_), do: false

  @spec should_scrape_homepage?(Company.t()) :: boolean()
  defp should_scrape_homepage?(%Company{} = company) do
    OpenTelemetry.Tracer.with_span "company_enrich.should_scrape_homepage?" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      cond do
        company.homepage_scraped == true ->
          false

        is_nil(company.primary_domain) or company.primary_domain == "" ->
          false

        true ->
          true
      end
    end
  end

  defp should_scrape_homepage?(_), do: false

  defp get_homepage_content(domain) do
    {:ok, url} = Core.Utils.UrlFormatter.to_https(domain)

    case Core.Researcher.Webpages.get_by_url(url) do
      {:ok, webpage} ->
        {:ok, webpage.content}

      {:error, :not_found} ->
        Tracing.error(:not_found, "No homepage content found for company",
          company_domain: domain
        )

        @err_not_found
    end
  end
end
