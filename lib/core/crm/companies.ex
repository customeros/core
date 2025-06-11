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

  It provides the core functionality for managing companies in the
  system, including creation, lookup, and enrichment coordination.
  The module handles domain normalization, company identification,
  and proper error handling for all operations.
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Core.Crm.Companies.Company
  alias Core.Crm.Companies.CompanyEnrich
  alias Core.Repo
  alias Core.Utils.IdGenerator
  alias Core.Utils.Media.Images
  alias Core.Utils.PrimaryDomainFinder
  alias Core.Utils.Tracing

  @spec get_or_create_by_domain(any()) ::
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
        %Company{} = company ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", "company already exists"}
          ])

          {:ok, company}

        nil ->
          # If not found by exact domain, proceed with primary domain check
          case PrimaryDomainFinder.get_primary_domain(domain) do
            {:ok, primary_domain} when primary_domain != "" ->
              case get_by_primary_domain(primary_domain) do
                nil ->
                  OpenTelemetry.Tracer.set_attributes([
                    {"company.found_by", "primary_domain"},
                    {"company.status", "created"}
                  ])

                  create_company_and_trigger_scraping(primary_domain)

                company ->
                  Tracing.ok()

                  OpenTelemetry.Tracer.set_attributes([
                    {"company.found_by", "primary_domain"},
                    {"company.status", "existing"}
                  ])

                  {:ok, company}
              end

            {:error, :no_primary_domain} ->
              Tracing.warning(:no_primary_domain, "No primary domain found for #{domain}")
              {:error, :no_primary_domain}

            {:error, reason} ->
              Tracing.error(inspect(reason))
              {:error, reason}
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

  @spec get_by_primary_domain(any()) :: Company.t() | nil
  def get_by_primary_domain(domain) when not is_binary(domain), do: nil

  def get_by_primary_domain(domain) when is_binary(domain) do
    OpenTelemetry.Tracer.with_span "company_service.get_by_primary_domain" do
      OpenTelemetry.Tracer.set_attributes([
        {"domain", domain}
      ])

      result = Repo.get_by(Company, primary_domain: domain)

      OpenTelemetry.Tracer.set_attributes([
        {"result.found", result != nil}
      ])

      result
    end
  end

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

  def get_or_create(%Company{} = company) do
    company_with_id =
      company
      |> Map.put(:id, IdGenerator.generate_id_21(Company.id_prefix()))

    case get_by_primary_domain(company.primary_domain) do
      nil ->
        case Company.changeset(company_with_id, %{}) |> Repo.insert() do
          {:ok, company} -> {:ok, company}
          {:error, changeset} -> {:error, changeset}
        end

      company ->
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
end
