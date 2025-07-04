defmodule Core.ScrapinContacts do
  @moduledoc """
  Context for ScrapIn contact enrichment and persistence.

  Provides functions to search and profile contacts using ScrapIn API,
  with caching and enrichment record storage.
  """

  import Ecto.Query

  alias Core.{
    Repo,
    ScrapinContact,
    ScrapinContactDetails,
    ScrapinContactResponseBody
  }

  alias Core.Utils.{IdGenerator, MapUtils}
  alias Core.Logger.ApiLogger, as: ApiLogger

  @vendor "scrapin"

  defp scrapin_api_key,
    do: Application.get_env(:core, :scrapin)[:scrapin_api_key]

  defp scrapin_base_url,
    do: Application.get_env(:core, :scrapin)[:scrapin_base_url]

  @doc """
  Search for a contact using ScrapIn with multiple parameters.
  Requires at least one of: first_name, last_name, or email.
  Returns {:ok, %ScrapinContactDetails{}} or {:error, :not_found}.
  """
  def search_contact_with_scrapin(attrs) do
    with {:ok, request_params} <- build_search_request_param(attrs),
         {:ok, api_params} <- build_search_params(attrs) do
      do_scrapin(:contact_search, request_params, api_params)
    end
  end

  @doc """
  Get contact profile by LinkedIn URL using ScrapIn.
  Returns {:ok, %ScrapinContactDetails{}} or {:error, :not_found}.
  """
  def profile_contact_with_scrapin(linkedin_url) when is_binary(linkedin_url) do
    normalized_linkedin_url = normalize_linkedin_url(linkedin_url)
    request_params = %{linkedin_url: normalized_linkedin_url}

    api_params = %{
      apikey: scrapin_api_key(),
      linkedInUrl: normalized_linkedin_url
    }

    do_scrapin(:contact_profile, request_params, api_params)
  end

  defp build_search_request_param(%{
         first_name: first_name,
         last_name: last_name,
         email: email,
         company_domain: domain,
         company_name: company_name
       })
       when is_binary(first_name) or is_binary(last_name) or is_binary(email) do
    request_params = %{}

    request_params =
      if first_name,
        do: Map.put(request_params, :first_name, first_name),
        else: request_params

    request_params =
      if last_name,
        do: Map.put(request_params, :last_name, last_name),
        else: request_params

    request_params =
      if email, do: Map.put(request_params, :email, email), else: request_params

    request_params =
      if domain,
        do: Map.put(request_params, :company_domain, domain),
        else: request_params

    request_params =
      if company_name && !domain,
        do: Map.put(request_params, :company_name, company_name),
        else: request_params

    {:ok, request_params}
  end

  defp build_search_request_param(_attrs) do
    {:error, :invalid_params}
  end

  defp build_search_params(%{
         first_name: first_name,
         last_name: last_name,
         email: email,
         company_domain: domain,
         company_name: company_name
       }) do
    params = %{apikey: scrapin_api_key()}

    params =
      if first_name, do: Map.put(params, :firstName, first_name), else: params

    params =
      if last_name, do: Map.put(params, :lastName, last_name), else: params

    params = if email, do: Map.put(params, :email, email), else: params

    params =
      if domain, do: Map.put(params, :companyDomain, domain), else: params

    params =
      if company_name && !domain,
        do: Map.put(params, :companyName, company_name),
        else: params

    {:ok, params}
  end

  defp do_scrapin(flow, request_params, api_params) do
    latest = get_latest_by_params(request_params)

    cond do
      latest && latest.success ->
        parse_contact_from_record(latest)

      latest && !latest.success ->
        {:error, :not_found}

      true ->
        with {:ok, response} <- call_scrapin(flow, api_params),
             true <- response.success do
          contact_struct = response.person

          case contact_struct do
            %ScrapinContactDetails{} = contact ->
              record_attrs = %{
                id: IdGenerator.generate_id_21(ScrapinContact.id_prefix()),
                linkedin_id: contact.linked_in_identifier,
                linkedin_alias: contact.public_identifier,
                request_param_linkedin: Map.get(request_params, :linkedin_url),
                request_param_first_name: Map.get(request_params, :first_name),
                request_param_last_name: Map.get(request_params, :last_name),
                request_param_email: Map.get(request_params, :email),
                request_param_company_domain:
                  Map.get(request_params, :company_domain),
                request_param_company_name:
                  Map.get(request_params, :company_name),
                data: Jason.encode!(response),
                success: true
              }

              %ScrapinContact{}
              |> ScrapinContact.changeset(record_attrs)
              |> Repo.insert()

              {:ok, contact}

            nil ->
              record_attrs = %{
                id: IdGenerator.generate_id_21(ScrapinContact.id_prefix()),
                request_param_linkedin: Map.get(request_params, :linkedin_url),
                request_param_first_name: Map.get(request_params, :first_name),
                request_param_last_name: Map.get(request_params, :last_name),
                request_param_email: Map.get(request_params, :email),
                request_param_company_domain:
                  Map.get(request_params, :company_domain),
                request_param_company_name:
                  Map.get(request_params, :company_name),
                data: Jason.encode!(response),
                success: false
              }

              %ScrapinContact{}
              |> ScrapinContact.changeset(record_attrs)
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

  defp get_latest_by_params(request_params) do
    query = ScrapinContact

    query =
      if request_params.linkedin_url do
        where(
          query,
          [s],
          s.request_param_linkedin == ^request_params.linkedin_url
        )
      else
        query
        |> where(
          [s],
          s.request_param_first_name == ^request_params.first_name and
            s.request_param_last_name == ^request_params.last_name and
            s.request_param_email == ^request_params.email and
            s.request_param_company_domain == ^request_params.company_domain and
            s.request_param_company_name == ^request_params.company_name
        )
      end

    query
    |> order_by([s], desc: s.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp parse_contact_from_record(%ScrapinContact{data: data})
       when is_binary(data) do
    with {:ok, decoded} <- Jason.decode(data, keys: :atoms),
         %{} = map <- MapUtils.to_snake_case_map(decoded) do
      response_struct = struct(ScrapinContactResponseBody, map)

      contact_struct =
        case response_struct.person do
          nil ->
            nil

          person_map when is_map(person_map) ->
            struct(ScrapinContactDetails, person_map)
        end

      response_struct = %{response_struct | person: contact_struct}

      case response_struct do
        %ScrapinContactResponseBody{person: %ScrapinContactDetails{} = contact} ->
          {:ok, contact}

        _ ->
          {:error, :not_found}
      end
    else
      _ ->
        {:error, :not_found}
    end
  end

  defp call_scrapin(:contact_search, params) do
    url = "#{scrapin_base_url()}/enrichment"
    do_call_scrapin(url, params)
  end

  defp call_scrapin(:contact_profile, params) do
    url = "#{scrapin_base_url()}/enrichment/profile"
    do_call_scrapin(url, params)
  end

  defp do_call_scrapin(url, params) do
    query = URI.encode_query(params)
    full_url = url <> "?" <> query

    case Finch.build(:get, full_url) |> ApiLogger.request(@vendor) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, map} ->
            snake_case_map = MapUtils.to_snake_case_map(map)

            # Convert person field to ScrapinContactDetails struct if present
            person_struct =
              case Map.get(snake_case_map, :person) do
                nil ->
                  nil

                person_map when is_map(person_map) ->
                  struct(ScrapinContactDetails, person_map)

                _ ->
                  nil
              end

            response_struct = struct(ScrapinContactResponseBody, snake_case_map)
            response_struct = %{response_struct | person: person_struct}

            {:ok, response_struct}

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

  defp normalize_linkedin_url(url) when is_binary(url) do
    url
    |> String.trim()
    |> String.trim_trailing("/")
  end
end
