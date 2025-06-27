defmodule Core.Crm.Companies.CompanyScrapinEnrich do
  @moduledoc """
  Enriches company data using Scrapin.
  """

  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query
  alias Core.Repo
  alias Core.Crm.Companies.Company
  alias Core.Utils.Tracing
  alias Core.ScrapinCompanies

  def enrich_start(company_id) do
    OpenTelemetry.Tracer.with_span "company_scrapin_enrich.enrich_start" do
      current_ctx = OpenTelemetry.Ctx.get_current()

      Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
        OpenTelemetry.Ctx.attach(current_ctx)
        enrich(company_id)
      end)
    end
  end

  def enrich(company_id) do
    OpenTelemetry.Tracer.with_span "company_scrapin_enrich.enrich" do
      with {:ok, company} <- fetch_company(company_id),
           :ok <- mark_enrich_attempt(company_id),
           {:ok, scrapin_company_details} <-
             get_scrapin_data_by_primary_domain(company),
           :ok <-
             update_company_with_scrapin_data(company, scrapin_company_details) do
        :ok
      else
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp fetch_company(company_id) do
    case Repo.get(Company, company_id) do
      nil ->
        Tracing.error(:not_found, "Company not found", company_id: company_id)
        {:error, :not_found}

      company ->
        {:ok, company}
    end
  end

  defp mark_enrich_attempt(company_id) do
    now = DateTime.utc_now()

    case Repo.update_all(
           from(c in Company, where: c.id == ^company_id),
           set: [scrapin_enrich_attempt_at: now],
           inc: [scrapin_enrichment_attempts: 1]
         ) do
      {0, _} ->
        Tracing.error(
          :update_failed,
          "Failed to mark scrapin enrichment attempt for company",
          company_id: company_id
        )

        {:error, :update_failed}

      {_count, _} ->
        :ok
    end
  end

  defp get_scrapin_data_by_primary_domain(company) do
    case ScrapinCompanies.search_company_with_scrapin(company.primary_domain) do
      {:ok, scrapin_company_details} ->
        {:ok, scrapin_company_details}

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, reason} ->
        Tracing.error(reason, "Failed to get scrapin data",
          company_id: company.id
        )

        {:error, reason}
    end
  end

  defp update_company_with_scrapin_data(company, scrapin_company_details) do
    case update_employee_count(company, scrapin_company_details) do
      {:error, reason} ->
        Logger.warning("Failed to update employee count",
          company_id: company.id,
          reason: reason
        )

      :ok ->
        :ok
    end

    case update_country_code(company, scrapin_company_details) do
      {:error, reason} ->
        Logger.warning("Failed to update country code",
          company_id: company.id,
          reason: reason
        )

      :ok ->
        :ok
    end

    case update_city_and_region(company, scrapin_company_details) do
      {:error, reason} ->
        Logger.warning("Failed to update city and region",
          company_id: company.id,
          reason: reason
        )

      :ok ->
        :ok
    end

    case update_company_name(company, scrapin_company_details) do
      {:error, reason} ->
        Logger.warning("Failed to update company name",
          company_id: company.id,
          reason: reason
        )

      :ok ->
        :ok
    end

    :ok
  end

  defp update_employee_count(company, scrapin_company_details) do
    # Only update if employee_count is not already set
    if is_nil(company.employee_count) do
      employee_count =
        get_employee_count_from_scrapin(scrapin_company_details)

      if employee_count && employee_count > 0 do
        case Repo.update_all(
               from(c in Company, where: c.id == ^company.id),
               set: [employee_count: employee_count]
             ) do
          {0, _} ->
            {:error, :update_failed}

          {_count, _} ->
            :ok
        end
      else
        :ok
      end
    else
      :ok
    end
  end

  defp get_employee_count_from_scrapin(scrapin_company_details) do
    cond do
      # Use employee_count if it's greater than 0
      scrapin_company_details.employee_count &&
          scrapin_company_details.employee_count > 0 ->
        scrapin_company_details.employee_count

      # Use employee_count_range start value if employee_count is 0 or missing
      scrapin_company_details.employee_count_range &&
          scrapin_company_details.employee_count_range.start ->
        scrapin_company_details.employee_count_range.start

      true ->
        nil
    end
  end

  defp update_country_code(company, scrapin_company_details) do
    # Only update if country_a2 is not set and country enrichment attempts > 2
    if is_nil(company.country_a2) && company.country_enrichment_attempts > 2 do
      country_code =
        get_country_code_from_headquarter(scrapin_company_details.headquarter)

      if country_code && String.length(country_code) == 2 do
        case Repo.update_all(
               from(c in Company, where: c.id == ^company.id),
               set: [country_a2: country_code]
             ) do
          {0, _} ->
            {:error, :update_failed}

          {_count, _} ->
            :ok
        end
      else
        :ok
      end
    else
      :ok
    end
  end

  defp get_country_code_from_headquarter(nil), do: nil

  defp get_country_code_from_headquarter(%{country: country})
       when is_binary(country),
       do: country

  defp get_country_code_from_headquarter(_), do: nil

  defp update_city_and_region(company, scrapin_company_details) do
    # Only update if company has a country and headquarter has a country
    if company.country_a2 && scrapin_company_details.headquarter &&
         scrapin_company_details.headquarter.country do
      update_city_and_region_if_countries_match(
        company,
        scrapin_company_details
      )
    else
      :ok
    end
  end

  defp update_city_and_region_if_countries_match(
         company,
         scrapin_company_details
       ) do
    headquarter_country = scrapin_company_details.headquarter.country

    # Check if countries match (case insensitive)
    if String.downcase(company.country_a2) ==
         String.downcase(headquarter_country) do
      perform_city_region_update(company, scrapin_company_details.headquarter)
    else
      :ok
    end
  end

  defp perform_city_region_update(company, headquarter) do
    updates = get_city_region_updates(headquarter)

    if length(updates) > 0 do
      case Repo.update_all(
             from(c in Company, where: c.id == ^company.id),
             set: updates
           ) do
        {0, _} ->
          {:error, :update_failed}

        {_count, _} ->
          :ok
      end
    else
      :ok
    end
  end

  defp get_city_region_updates(headquarter) do
    updates = []

    updates =
      if headquarter.city && headquarter.city != "",
        do: Keyword.put(updates, :city, headquarter.city),
        else: updates

    updates =
      if headquarter.geographic_area && headquarter.geographic_area != "",
        do: Keyword.put(updates, :region, headquarter.geographic_area),
        else: updates

    updates
  end

  defp update_company_name(company, scrapin_company_details) do
    # Only update if company name is empty/nil and name attempts > 2
    if (is_nil(company.name) || company.name == "") &&
         company.name_enrichment_attempts > 2 do
      company_name = scrapin_company_details.name

      if company_name && company_name != "" do
        case Repo.update_all(
               from(c in Company, where: c.id == ^company.id),
               set: [name: company_name]
             ) do
          {0, _} ->
            {:error, :update_failed}

          {_count, _} ->
            :ok
        end
      else
        :ok
      end
    else
      :ok
    end
  end
end
