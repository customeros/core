defmodule Core.Crm.Companies.CompanyEnrich do
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query
  alias Core.Repo
  alias Core.Crm.Companies.Company
  alias Core.Crm.Companies.Enrichments
  alias Core.Crm.Industries
  alias Core.Utils.Errors
  alias Core.Utils.Media.Images
  alias Core.Utils.Tracing

  @type enrich_industry_error :: :not_found | :update_failed | :industry_not_found | :invalid_request | :ai_timeout | :invalid_ai_response
  @type enrich_country_error :: :not_found | :update_failed | :invalid_request | :ai_timeout | :invalid_ai_response
  @type enrich_name_error :: :not_found | :update_failed | :invalid_request | :ai_timeout | :invalid_ai_response
  @type enrich_icon_error :: :not_found | :update_failed | :invalid_request | :ai_timeout | :invalid_ai_response | :download_failed | :storage_failed

  def enrich_industry_task(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_industry_task" do
      span_ctx = OpenTelemetry.Tracer.current_span_ctx()

      Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
        OpenTelemetry.Tracer.set_current_span(span_ctx)
        enrich_industry(company_id)
      end)
    end
  end

  @spec enrich_industry(String.t()) :: :ok | {:error, enrich_industry_error()}
  def enrich_industry(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_industry" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company_id}
      ])

      case Repo.get(Company, company_id) do
        nil ->
          Tracing.error(:not_found)

          Logger.error(
            "Company #{company_id} not found for industry enrichment"
          )

          Errors.error(:not_found)

        company ->
          if should_enrich_industry?(company) do
            {count, _} =
              Repo.update_all(
                from(c in Company, where: c.id == ^company_id),
                set: [industry_enrich_attempt_at: DateTime.utc_now()],
                inc: [industry_enrichment_attempts: 1]
              )

            if count > 0 do
              # Get industry code from AI
              case Enrichments.Industry.identify(%{
                     domain: company.primary_domain,
                     homepage_content: company.homepage_content
                   }) do
                {:ok, industry_code} ->
                  OpenTelemetry.Tracer.set_attributes([
                    {"ai.industry.code", industry_code}
                  ])

                  # Get industry name from our industries table
                  case Industries.get_by_code(industry_code) do
                    nil ->
                      OpenTelemetry.Tracer.set_status(
                        :error,
                        :industry_not_found
                      )

                      OpenTelemetry.Tracer.set_attributes([
                        {"error.reason", "Industry not found"}
                      ])

                      Logger.error(
                        "Industry code #{industry_code} not found in industries table for company #{company_id}"
                      )

                      {:error, :industry_not_found}

                    industry ->
                      # Update company with industry code and name
                      {update_count, _} =
                        Repo.update_all(
                          from(c in Company, where: c.id == ^company_id),
                          set: [
                            industry_code: industry.code,
                            industry: industry.name
                          ]
                        )

                      if update_count == 0 do
                        Tracing.error(:update_failed)

                        Logger.error(
                          "Failed to update industry for company #{company_id} (domain: #{company.primary_domain})"
                        )

                        Errors.error(:update_failed)
                      else
                        :ok
                      end
                  end

                {:error, {:invalid_request, reason}} ->
                  Logger.error(
                    "Invalid request for industry enrichment for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                  )

                  Tracing.error(:invalid_request)

                  {:error, :invalid_request}

                {:error, reason} ->
                  Logger.error(
                    "Failed to get industry code from AI for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                  )

                  Tracing.error(reason)

                  {:error, reason}
              end
            else
              Tracing.error(:update_failed)

              Logger.error(
                "Failed to mark industry enrichment attempt for company #{company_id}"
              )

              Errors.error(:update_failed)
            end
          else
            :ok
          end
      end
    end
  end

  def enrich_name_task(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_name_task" do
      span_ctx = OpenTelemetry.Tracer.current_span_ctx()

      Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
        OpenTelemetry.Tracer.set_current_span(span_ctx)
        enrich_name(company_id)
      end)
    end
  end

  @spec enrich_name(String.t()) :: :ok | {:error, enrich_name_error()}
  def enrich_name(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_name" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company_id}
      ])

      case Repo.get(Company, company_id) do
        nil ->
          Tracing.error(:not_found)

          Logger.error("Company #{company_id} not found for name enrichment")

          Errors.error(:not_found)

        company ->
          if should_enrich_name?(company) do
            {count, _} =
              Repo.update_all(
                from(c in Company, where: c.id == ^company_id),
                set: [name_enrich_attempt_at: DateTime.utc_now()],
                inc: [name_enrichment_attempts: 1]
              )

            if count > 0 do
              # Get name from AI
              case Enrichments.Name.identify(%{
                     domain: company.primary_domain,
                     homepage_content: company.homepage_content
                   }) do
                {:ok, name} ->
                  OpenTelemetry.Tracer.set_attributes([
                    {"ai.name", name}
                  ])

                  {update_count, _} =
                    Repo.update_all(
                      from(c in Company, where: c.id == ^company_id),
                      set: [name: name]
                    )

                  if update_count == 0 do
                    Tracing.error(:update_failed)

                    Logger.error(
                      "Failed to update name for company #{company_id} (domain: #{company.primary_domain})"
                    )

                    Errors.error(:update_failed)
                  end

                {:error, reason} ->
                  Logger.error(
                    "Failed to get name from AI for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                  )

                  Tracing.error(inspect(reason))

                  {:error, reason}
              end
            else
              Tracing.error(:update_failed)

              Logger.error(
                "Failed to mark name enrichment attempt for company #{company_id}"
              )

              Errors.error(:update_failed)
            end
          else
            :ok
          end
      end
    end
  end

  def enrich_country_task(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_country_task" do
      span_ctx = OpenTelemetry.Tracer.current_span_ctx()

      Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
        OpenTelemetry.Tracer.set_current_span(span_ctx)
        enrich_country(company_id)
      end)
    end
  end

  @spec enrich_country(String.t()) :: :ok | {:error, enrich_country_error()}
  def enrich_country(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_country" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company_id}
      ])

      case Repo.get(Company, company_id) do
        nil ->
          Tracing.error(:not_found)

          Logger.error("Company #{company_id} not found for country enrichment")

          Errors.error(:not_found)

        company ->
          if should_enrich_country?(company) do
            {count, _} =
              Repo.update_all(
                from(c in Company, where: c.id == ^company_id),
                set: [country_enrich_attempt_at: DateTime.utc_now()],
                inc: [country_enrichment_attempts: 1]
              )

            if count > 0 do
              # Get name from AI
              case Enrichments.Location.identifyCountryCodeA2(%{
                     domain: company.primary_domain,
                     homepage_content: company.homepage_content
                   }) do
                {:ok, "XX"} ->
                  OpenTelemetry.Tracer.set_attributes([
                    {"ai.country_code_a2", "XX"}
                  ])

                  :ok

                {:ok, country_code_a2} ->
                  OpenTelemetry.Tracer.set_attributes([
                    {"ai.country_code_a2", country_code_a2}
                  ])

                  # Ensure country code is uppercase before saving
                  country_code_a2_uppercase = String.upcase(country_code_a2)

                  {update_count, _} =
                    Repo.update_all(
                      from(c in Company, where: c.id == ^company_id),
                      set: [country_a2: country_code_a2_uppercase]
                    )

                  if update_count == 0 do
                    Tracing.error(:update_failed)

                    Logger.error(
                      "Failed to update country code for company #{company_id} (domain: #{company.primary_domain})"
                    )

                    Errors.error(:update_failed)
                  end

                {:error, reason} ->
                  Logger.error(
                    "Failed to get country code from AI for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                  )

                  Tracing.error(inspect(reason))

                  {:error, reason}
              end
            else
              Tracing.error(:update_failed)

              Logger.error(
                "Failed to mark country enrichment attempt for company #{company_id}"
              )

              Errors.error(:update_failed)
            end
          else
            :ok
          end
      end
    end
  end

  def enrich_icon_task(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_icon_task" do
      span_ctx = OpenTelemetry.Tracer.current_span_ctx()

      Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
        OpenTelemetry.Tracer.set_current_span(span_ctx)
        enrich_icon(company_id)
      end)
    end
  end

  @spec enrich_icon(String.t()) :: :ok | {:error, enrich_icon_error()}
  def enrich_icon(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_icon" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company_id}
      ])

      case Repo.get(Company, company_id) do
        nil ->
          Tracing.error(:not_found)

          Logger.error("Company #{company_id} not found for country enrichment")

          Errors.error(:not_found)

        company ->
          if should_enrich_icon?(company) do
            {count, _} =
              Repo.update_all(
                from(c in Company, where: c.id == ^company_id),
                set: [icon_enrich_attempt_at: DateTime.utc_now()],
                inc: [icon_enrichment_attempts: 1]
              )

            if count > 0 do
              # Get Brandfetch client ID from configuration
              client_id =
                Application.get_env(:core, :brandfetch)[:client_id] ||
                  raise "BRANDFETCH_CLIENT_ID is not configured"

              # Construct Brandfetch URL
              brandfetch_url =
                "https://cdn.brandfetch.io/#{company.primary_domain}/type/fallback/404/w/400/h/400?c=#{client_id}"

              # Download and store the icon
              case Images.download_image(brandfetch_url) do
                {:ok, image_data} ->
                  # Only proceed with storage if we got actual image data
                  case Images.store_image(
                         image_data,
                         "image/jpeg",
                         brandfetch_url,
                         %{
                           generate_name: true,
                           path: "_companies"
                         }
                       ) do
                    {:ok, storage_key} ->
                      # Update company with the icon storage key
                      {update_count, _} =
                        Repo.update_all(
                          from(c in Company, where: c.id == ^company_id),
                          set: [icon_key: storage_key]
                        )

                      if update_count == 0 do
                        Tracing.error(:update_failed)

                        Logger.error(
                          "Failed to update icon key for company #{company_id} (domain: #{company.primary_domain})"
                        )

                        Errors.error(:update_failed)
                      else
                        :ok
                      end

                    {:error, reason} ->
                      Tracing.error(inspect(reason))

                      Logger.error(
                        "Failed to store icon for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                      )

                      {:error, reason}
                  end

                {:error, reason} ->
                  Tracing.error(inspect(reason))

                  Logger.error(
                    "Failed to download icon for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                  )

                  {:error, reason}
              end
            else
              Tracing.error(:update_failed)

              Logger.error(
                "Failed to mark icon enrichment attempt for company #{company_id}"
              )

              Errors.error(:update_failed)
            end
          else
            :ok
          end
      end
    end
  end

  # Private helper methods
  @spec should_enrich_industry?(%Company{}) :: boolean()
  defp should_enrich_industry?(%Company{} = company) do
    OpenTelemetry.Tracer.with_span "company_enrich.should_enrich_industry?" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      if is_nil(company.homepage_content) or company.homepage_content == "" do
        OpenTelemetry.Tracer.set_attributes([
          {"result", "false"}
        ])

        false
      else
        result = is_nil(company.industry_code) or company.industry_code == ""

        OpenTelemetry.Tracer.set_attributes([
          {"result", result}
        ])

        result
      end
    end
  end

  defp should_enrich_industry?(_), do: false

  @spec should_enrich_name?(%Company{}) :: boolean()
  defp should_enrich_name?(%Company{} = company) do
    OpenTelemetry.Tracer.with_span "company_enrich.should_enrich_name?" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      if is_nil(company.homepage_content) or company.homepage_content == "" do
        OpenTelemetry.Tracer.set_attributes([
          {"result", "false"}
        ])

        false
      else
        result = is_nil(company.name) or company.name == ""

        OpenTelemetry.Tracer.set_attributes([
          {"result", result}
        ])

        result
      end
    end
  end

  defp should_enrich_name?(_), do: false

  @spec should_enrich_country?(%Company{}) :: boolean()
  defp should_enrich_country?(%Company{} = company) do
    OpenTelemetry.Tracer.with_span "company_enrich.should_enrich_country?" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      if is_nil(company.homepage_content) or company.homepage_content == "" do
        OpenTelemetry.Tracer.set_attributes([
          {"result", "false"}
        ])

        false
      else
        result = is_nil(company.country_a2) or company.country_a2 == ""

        OpenTelemetry.Tracer.set_attributes([
          {"result", result}
        ])

        result
      end
    end
  end

  defp should_enrich_country?(_), do: false

  @spec should_enrich_icon?(%Company{}) :: boolean()
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
end
