defmodule Core.Crm.Companies do
  @moduledoc """
  Manages company data and operations.

  This module manages:
  * Company creation and retrieval
  * Domain-based company lookup
  * Primary domain resolution
  * Company enrichment triggering
  * Icon URL management
  * Error handling and tracing

  For external company mappings (e.g., HubSpot), see `Core.Crm.Companies.ExternalCompanies`.

  It provides the core functionality for managing companies in the
  system, including creation, lookup, and enrichment coordination.
  The module handles domain normalization, company identification,
  and proper error handling for all operations.
  """

  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query
  alias Ecto.Repo
  alias Core.Crm.Companies.{Company, CompanyEnrich}
  alias Core.Repo
  alias Core.Utils.IdGenerator
  alias Core.Utils.Media.Images
  alias Core.Utils.PrimaryDomainFinder
  alias Core.Utils.Tracing
  alias Core.ScrapinCompanies

  @spec get_or_create_by_domain(String.t()) ::
          {:ok, Company.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def get_or_create_by_domain(domain) when not is_binary(domain),
    do: {:error, "domain must be a string"}

  def get_or_create_by_domain(domain) when is_binary(domain) do
    OpenTelemetry.Tracer.with_span "company_service.get_or_create_by_domain" do
      OpenTelemetry.Tracer.set_attributes([
        {"domain", domain}
      ])

      # First check if company exists with this exact domain
      case get_by_primary_domain(domain) do
        {:ok, company} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", "company already exists"}
          ])

          {:ok, company}

        {:error, :not_found} ->
          case PrimaryDomainFinder.get_primary_domain(domain) do
            {:ok, primary_domain} when primary_domain != "" ->
              case get_by_primary_domain(primary_domain) do
                {:error, :not_found} ->
                  OpenTelemetry.Tracer.set_attributes([
                    {"company.found_by", "primary_domain"},
                    {"company.status", "created"}
                  ])

                  create_company_and_trigger_scraping(primary_domain)

                {:ok, company} ->
                  Tracing.ok()

                  OpenTelemetry.Tracer.set_attributes([
                    {"company.found_by", "primary_domain"},
                    {"company.status", "existing"}
                  ])

                  {:ok, company}
              end

            {:error, :no_primary_domain} ->
              Tracing.warning(
                :no_primary_domain,
                "No primary domain found for #{domain}"
              )

              {:error, :no_primary_domain}

            {:error, reason} ->
              Tracing.error(inspect(reason))
              {:error, reason}
          end
      end
    end
  end

  def get_or_create_company_by_linkedin_id(linkedin_id) do
    OpenTelemetry.Tracer.with_span "company_service.get_or_create_company_by_linkedin_id" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.linkedin_id", linkedin_id}
      ])

      # First try to get existing company by linkedin_id
      case get_by_linkedin_id(linkedin_id) do
        {:ok, company} ->
          {:ok, company}

        {:error, :not_found} ->
          # Company not found, create new one
          linkedin_url = "https://www.linkedin.com/company/#{linkedin_id}"

          case ScrapinCompanies.profile_company_with_scrapin(linkedin_url) do
            {:ok, scrapin_company_details} ->
              case ScrapinCompanies.get_scrapin_company_record_by_linkedin_id(
                     scrapin_company_details.linked_in_id
                   ) do
                {:ok, scrapin_company_record} ->
                  case get_or_create_by_domain(scrapin_company_record.domain) do
                    {:ok, company} ->
                      if scrapin_company_record.domain ==
                           scrapin_company_record.linkedin_domain do
                        set_company_linkedin_id(company, linkedin_id)
                      else
                        {:ok, company}
                      end

                    {:error, reason} ->
                      {:error, reason}
                  end

                {:error, reason} ->
                  {:error, reason}
              end

            {:error, :not_found} ->
              {:error, :not_found}
          end
      end
    end
  end

  defp create_company_and_trigger_scraping(primary_domain)
       when is_binary(primary_domain) do
    OpenTelemetry.Tracer.with_span "company_service.create_company_and_trigger_scraping" do
      OpenTelemetry.Tracer.set_attributes([
        {"primary_domain", primary_domain}
      ])

      case create_with_domain(primary_domain) do
        {:ok, company} ->
          CompanyEnrich.scrape_homepage_start(company.id)
          Tracing.ok()
          {:ok, company}

        {:error, reason} ->
          Tracing.error(reason)
          {:error, reason}
      end
    end
  end

  @spec create_with_domain(any()) ::
          {:ok, Company.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def create_with_domain(domain) when not is_binary(domain),
    do: {:error, "domain must be a string"}

  def create_with_domain(domain) when is_binary(domain) do
    OpenTelemetry.Tracer.with_span "company_service.create_with_domain" do
      OpenTelemetry.Tracer.set_attributes([
        {"domain", domain}
      ])

      result =
        %Company{primary_domain: domain}
        |> Map.put(:id, IdGenerator.generate_id_21(Company.id_prefix()))
        |> Company.changeset(%{})
        |> Repo.insert()

      case result do
        {:ok, company} ->
          Tracing.ok()
          {:ok, company}

        {:error, _changeset} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.success", false},
            {"error.type", "validation_failed"}
          ])

          Tracing.error("validation_failed")
          {:error, :validation_failed}
      end
    end
  end

  @spec get_by_primary_domain(any()) ::
          {:ok, Company.t()} | {:error, :not_found} | nil
  def get_by_primary_domain(domain) when not is_binary(domain), do: nil

  def get_by_primary_domain(domain) when is_binary(domain) do
    OpenTelemetry.Tracer.with_span "company_service.get_by_primary_domain" do
      OpenTelemetry.Tracer.set_attributes([
        {"domain", domain}
      ])

      case Repo.get_by(Company, primary_domain: domain) do
        nil ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.found", false}
          ])

          {:error, :not_found}

        %Company{} = company ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.found", true}
          ])

          {:ok, company}
      end
    end
  end

  @spec get_by_id(binary()) :: {:ok, Company.t()} | {:error, :not_found}
  def get_by_id(id) when is_binary(id) do
    OpenTelemetry.Tracer.with_span "company_service.get_by_id" do
      OpenTelemetry.Tracer.set_attributes([
        {"id", id}
      ])

      case Repo.get_by(Company, id: id) do
        nil ->
          {:error, :not_found}

        %Company{} = company ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.found", true}
          ])

          {:ok, company}
      end
    end
  end

  @spec get_by_linkedin_id(binary()) ::
          {:ok, Company.t()} | {:error, :not_found}
  def get_by_linkedin_id(linkedin_id) when is_binary(linkedin_id) do
    OpenTelemetry.Tracer.with_span "company_service.get_by_linkedin_id" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.linkedin_id", linkedin_id}
      ])

      # Get all companies with this LinkedIn ID in their linkedin_ids array
      companies =
        Repo.all(from c in Company, where: ^linkedin_id in c.linkedin_ids)

      case companies do
        [] ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.found", false}
          ])

          {:error, :not_found}

        [company] ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.found", true}
          ])

          {:ok, company}

        companies when length(companies) > 1 ->
          case find_company_with_matching_domain(companies, linkedin_id) do
            {:ok, company} ->
              OpenTelemetry.Tracer.set_attributes([
                {"result.found", true},
                {"result.multiple_found", true},
                {"result.domain_matched", true}
              ])

              {:ok, company}

            {:error, :no_domain_match} ->
              company = List.first(companies)

              OpenTelemetry.Tracer.set_attributes([
                {"result.found", true},
                {"result.multiple_found", true},
                {"result.domain_matched", false}
              ])

              {:ok, company}
          end
      end
    end
  end

  defp find_company_with_matching_domain(companies, linkedin_id) do
    case get_scrapin_company_domain(linkedin_id) do
      {:ok, scrapin_domain} when is_binary(scrapin_domain) ->
        matching_company =
          Enum.find(companies, fn company ->
            company.primary_domain == scrapin_domain
          end)

        if matching_company do
          {:ok, matching_company}
        else
          {:error, :no_domain_match}
        end

      _ ->
        # No scrapin domain found or it's nil
        {:error, :no_domain_match}
    end
  end

  defp get_scrapin_company_domain(linkedin_id) do
    import Ecto.Query

    case Repo.one(
           from sc in Core.ScrapinCompany,
             where: sc.linkedin_id == ^linkedin_id,
             order_by: [desc: sc.inserted_at],
             limit: 1,
             select: sc.domain
         ) do
      nil -> {:error, :not_found}
      domain -> {:ok, domain}
    end
  end

  @spec get_or_create(Company.t()) ::
          {:ok, Company.t()} | {:error, Ecto.Changeset.t()}
  def get_or_create(%Company{} = company) do
    company_with_id =
      company
      |> Map.put(:id, IdGenerator.generate_id_21(Company.id_prefix()))

    case get_by_primary_domain(company.primary_domain) do
      {:error, :not_found} ->
        case Company.changeset(company_with_id, %{}) |> Repo.insert() do
          {:ok, company} -> {:ok, company}
          {:error, changeset} -> {:error, changeset}
        end

      {:ok, company} ->
        {:ok, company}
    end
  end

  @spec get_icon_url(String.t()) ::
          {:ok, String.t() | nil} | {:error, :not_found}
  def get_icon_url(company_id) do
    case Repo.get(Company, company_id) do
      nil -> {:error, :not_found}
      %Company{} = company -> {:ok, Images.get_cdn_url(company.icon_key)}
    end
  end

  def set_company_linkedin_id(company, linkedin_id) do
    # Add the linkedin_id to the linkedin_ids array if it's not already there
    current_linkedin_ids = company.linkedin_ids || []

    if linkedin_id not in current_linkedin_ids do
      updated_linkedin_ids = [linkedin_id | current_linkedin_ids]

      case Repo.update_all(
             from(c in Company, where: c.id == ^company.id),
             set: [linkedin_ids: updated_linkedin_ids]
           ) do
        {0, _} ->
          {:error, :update_failed}

        {_count, _} ->
          {:ok, %{company | linkedin_ids: updated_linkedin_ids}}
      end
    else
      {:ok, company}
    end
  end
end
