defmodule Core.ScrapinCompanies do
  @moduledoc """
  Context for ScrapIn company enrichment and persistence.

  Provides functions to search and profile companies using ScrapIn API,
  with caching and enrichment record storage.
  """

  import Ecto.Query

  alias Core.{
    Repo,
    ScrapinCompany,
    ScrapinCompanyDetails,
    ScrapinCompanyResponseBody
  }

  alias Core.Utils.{IdGenerator, PrimaryDomainFinder, MapUtils, StructUtils}
  alias Core.Logger.ApiLogger, as: ApiLogger

  @vendor "scrapin"

  defp scrapin_api_key,
    do: Application.get_env(:core, :scrapin)[:scrapin_api_key]

  defp scrapin_base_url,
    do: Application.get_env(:core, :scrapin)[:scrapin_base_url]

  @doc """
  Search for a company by domain using ScrapIn.
  Returns {:ok, %ScrapinCompanyDetails{}} or {:error, :not_found}.
  """
  def search_company_with_scrapin(domain) when is_binary(domain) do
    do_scrapin(:company_search, domain)
  end

  @doc """
  Get company profile by LinkedIn URL using ScrapIn.
  Returns {:ok, %ScrapinCompanyDetails{}} or {:error, :not_found}.
  """
  def profile_company_with_scrapin(linkedin_url) when is_binary(linkedin_url) do
    do_scrapin(:company_profile, linkedin_url)
  end

  @doc """
  Get latest cached company data by domain.
  Returns {:ok, %ScrapinCompanyDetails{}} or {:error, :not_found}.
  """
  def get_company_data_by_domain(domain) when is_binary(domain) do
    latest = get_latest_by_domain(domain)

    case latest do
      %ScrapinCompany{company_found: true} = record ->
        parse_company_from_record(record)

      %ScrapinCompany{company_found: false} ->
        {:error, :not_found}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Get latest ScrapinCompany record by LinkedIn ID.
  Returns {:ok, %ScrapinCompany{}} or {:error, :not_found}.
  """
  def get_scrapin_company_record_by_linkedin_id(linkedin_id)
      when is_binary(linkedin_id) do
    latest = get_latest_by_linkedin_id(linkedin_id)

    case latest do
      %ScrapinCompany{company_found: true} = record ->
        {:ok, record}

      %ScrapinCompany{company_found: false} ->
        {:error, :not_found}

      nil ->
        {:error, :not_found}
    end
  end

  # --- Private helpers ---
  defp do_scrapin(flow, request_param) do
    latest = get_latest_by_param(request_param)

    cond do
      latest && latest.company_found ->
        parse_company_from_record(latest)

      latest && !latest.company_found ->
        {:error, :not_found}

      true ->
        with {:ok, response} <- call_scrapin(flow, request_param),
             true <- response.success do
          company_struct =
            case response.company do
              nil ->
                nil

              map when is_map(map) ->
                StructUtils.safe_struct(map, ScrapinCompanyDetails)
            end

          case company_struct do
            %ScrapinCompanyDetails{} = company ->
              {:ok, domain} = extract_domain(company.website_url)

              record_attrs = %{
                id: IdGenerator.generate_id_21(ScrapinCompany.id_prefix()),
                linkedin_id: company.linked_in_id,
                linkedin_alias: company.universal_name,
                domain: domain,
                request_param: request_param,
                data: Jason.encode!(response),
                success: true,
                company_found: true
              }

              %ScrapinCompany{}
              |> ScrapinCompany.changeset(record_attrs)
              |> Repo.insert()

              {:ok, company}

            nil ->
              record_attrs = %{
                id: IdGenerator.generate_id_21(ScrapinCompany.id_prefix()),
                request_param: request_param,
                data: Jason.encode!(response),
                success: true,
                company_found: false
              }

              %ScrapinCompany{}
              |> ScrapinCompany.changeset(record_attrs)
              |> Repo.insert()

              {:error, :not_found}

            _other ->
              {:error, :not_found}
          end
        else
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp get_latest_by_param(request_param) do
    ScrapinCompany
    |> where([s], s.request_param == ^request_param)
    |> order_by([s], desc: s.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp get_latest_by_domain(domain) do
    ScrapinCompany
    |> where([s], s.domain == ^domain)
    |> order_by([s], desc: s.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp get_latest_by_linkedin_id(linkedin_id) do
    ScrapinCompany
    |> where([s], s.linkedin_id == ^linkedin_id)
    |> order_by([s], desc: s.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp parse_company_from_record(%ScrapinCompany{data: data})
       when is_binary(data) do
    with {:ok, decoded} <- Jason.decode(data, keys: :atoms),
         %{} = map <- MapUtils.to_snake_case_map(decoded) do
      response_struct = StructUtils.safe_struct(map, ScrapinCompanyResponseBody)

      company_struct =
        case response_struct.company do
          nil ->
            nil

          company_map when is_map(company_map) ->
            StructUtils.safe_struct(company_map, ScrapinCompanyDetails)
        end

      response_struct = %{response_struct | company: company_struct}

      case response_struct do
        %ScrapinCompanyResponseBody{company: %ScrapinCompanyDetails{} = company} ->
          {:ok, company}

        _ ->
          {:error, :not_found}
      end
    else
      _ ->
        {:error, :not_found}
    end
  end

  defp call_scrapin(:company_search, domain) do
    url = "#{scrapin_base_url()}/enrichment/company/domain"
    params = %{apikey: scrapin_api_key(), domain: domain}
    do_call_scrapin(url, params)
  end

  defp call_scrapin(:company_profile, linkedin_url) do
    url = "#{scrapin_base_url()}/enrichment/company"
    params = %{apikey: scrapin_api_key(), linkedInUrl: linkedin_url}
    do_call_scrapin(url, params)
  end

  defp do_call_scrapin(url, params) do
    query = URI.encode_query(params)
    full_url = url <> "?" <> query

    case Finch.build(:get, full_url) |> ApiLogger.request(@vendor) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, map} ->
            {:ok,
             StructUtils.safe_struct(
               MapUtils.to_snake_case_map(map),
               ScrapinCompanyResponseBody
             )}

          _ ->
            {:error, :invalid_response}
        end

      {:ok, %{status: status}} when status in 400..499 ->
        {:error, :not_found}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_domain(nil), do: {:ok, nil}

  defp extract_domain(website_url) when is_binary(website_url) do
    case Core.Utils.DomainExtractor.extract_base_domain(website_url) do
      {:ok, website_domain} ->
        case PrimaryDomainFinder.get_primary_domain(website_domain) do
          {:ok, domain} when is_binary(domain) -> {:ok, domain}
          _ -> {:ok, nil}
        end

      _ ->
        case PrimaryDomainFinder.get_primary_domain(website_url) do
          {:ok, domain} when is_binary(domain) -> {:ok, domain}
          _ -> {:ok, nil}
        end
    end
  end
end
