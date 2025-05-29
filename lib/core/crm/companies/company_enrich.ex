defmodule Core.Crm.Companies.CompanyEnrich do
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query
  alias Core.Repo
  alias Core.Crm.Companies.Company
  alias Core.Crm.Companies.Enrichments
  alias Core.Crm.Industries
  alias Core.Utils.Errors

  def enrich_industry_task(company_id) do
    span_ctx = OpenTelemetry.Tracer.current_span_ctx()

    Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
      OpenTelemetry.Tracer.set_current_span(span_ctx)
      enrich_industry(company_id)
    end)
  end

  def enrich_industry(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_industry" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company_id}
      ])

      case Repo.get(Company, company_id) do
        nil ->
          OpenTelemetry.Tracer.set_status(:error, :not_found)

          OpenTelemetry.Tracer.set_attributes([
            {"error.reason", "Company not found"}
          ])

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
                        OpenTelemetry.Tracer.set_status(:error, :update_failed)

                        OpenTelemetry.Tracer.set_attributes([
                          {"error.reason", "Failed to update company industry"}
                        ])

                        Logger.error(
                          "Failed to update industry for company #{company_id} (domain: #{company.primary_domain})"
                        )

                        Errors.error(:update_failed)
                      end
                  end

                {:error, reason} ->
                  Logger.error(
                    "Failed to get industry code from AI for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                  )
                  OpenTelemetry.Tracer.set_status(:error, inspect(reason))
                  OpenTelemetry.Tracer.set_attributes([
                    {"error.reason", inspect(reason)}
                  ])
              end
            else
              OpenTelemetry.Tracer.set_status(:error, :update_failed)

              OpenTelemetry.Tracer.set_attributes([
                {"error.reason", "Failed to update company enrichment attempt"}
              ])

              Logger.error(
                "Failed to mark industry enrichment attempt for company #{company_id}"
              )

              Errors.error(:update_failed)
            end
          end
      end
    end
  end

  def enrich_name_task(company_id) do
    span_ctx = OpenTelemetry.Tracer.current_span_ctx()

    Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
      OpenTelemetry.Tracer.set_current_span(span_ctx)
      enrich_name(company_id)
    end)
  end

  def enrich_name(company_id) do
    OpenTelemetry.Tracer.with_span "company_enrich.enrich_name" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company_id}
      ])

      case Repo.get(Company, company_id) do
        nil ->
          OpenTelemetry.Tracer.set_status(:error, :not_found)

          OpenTelemetry.Tracer.set_attributes([
            {"error.reason", "Company not found"}
          ])

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
                    OpenTelemetry.Tracer.set_status(:error, :update_failed)

                    OpenTelemetry.Tracer.set_attributes([
                      {"error.reason", "Failed to update company name"}
                    ])

                    Logger.error(
                      "Failed to update industry for company #{company_id} (domain: #{company.primary_domain})"
                    )

                    Errors.error(:update_failed)
                  end

                {:error, reason} ->
                  Logger.error(
                    "Failed to get name from AI for company #{company_id} (domain: #{company.primary_domain}): #{inspect(reason)}"
                  )
                  OpenTelemetry.Tracer.set_status(:error, inspect(reason))
                  OpenTelemetry.Tracer.set_attributes([
                    {"error.reason", inspect(reason)}
                  ])
              end
            else
              OpenTelemetry.Tracer.set_status(:error, :update_failed)

              OpenTelemetry.Tracer.set_attributes([
                {"error.reason", "Failed to update company enrichment attempt"}
              ])

              Logger.error(
                "Failed to mark industry enrichment attempt for company #{company_id}"
              )

              Errors.error(:update_failed)
            end
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
end
