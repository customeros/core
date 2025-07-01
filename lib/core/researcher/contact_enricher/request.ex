defmodule Core.Researcher.ContactEnricher.Request do
  alias Core.Utils.DomainValidator

  @err_first_name_empty {:error, "first name is empty"}
  @err_invalid_first_name {:error, "invalid first name"}
  @err_last_name_empty {:error, "last name is empty"}
  @err_invalid_last_name {:error, "invalid last name"}
  @err_invalid_domain {:error, "invalid domain"}
  @err_invalid_search_type {:error, "invalid search type"}
  @err_company_details_empty {:error,
                              "both company name and domain are empty, one is required"}

  @type search_type :: :email | :phone | :email_and_phone
  @type t :: %__MODULE__{
          first_name: String.t(),
          last_name: String.t(),
          company_name: String.t() | nil,
          company_domain: String.t() | nil,
          linkedin_url: String.t() | nil,
          search_type: search_type,
          contact_id: String.t() | nil
        }

  defstruct [
    :first_name,
    :last_name,
    :company_name,
    :company_domain,
    :linkedin_url,
    :search_type,
    :contact_id
  ]

  def new(first_name, last_name, search_type, opts \\ []) do
    req = %__MODULE__{
      first_name: first_name,
      last_name: last_name,
      search_type: search_type,
      company_name: opts[:company_name],
      company_domain: opts[:company_domain],
      linkedin_url: opts[:linkedin_url],
      contact_id: opts[:contact_id]
    }

    validate(req)
  end

  defp validate(%__MODULE__{} = req) do
    with :ok <- validate_first_name(req.first_name),
         :ok <- validate_last_name(req.last_name),
         :ok <- validate_search_type(req.search_type),
         :ok <-
           validate_has_company_name_or_domain(
             req.company_name,
             req.company_domain
           ),
         :ok <- validate_company_domain(req.company_domain) do
      req
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_first_name(nil), do: @err_first_name_empty
  defp validate_first_name(""), do: @err_first_name_empty

  defp validate_first_name(first_name)
       when not is_binary(first_name),
       do: @err_invalid_first_name

  defp validate_first_name(_), do: :ok

  defp validate_last_name(nil), do: @err_last_name_empty
  defp validate_last_name(""), do: @err_last_name_empty

  defp validate_last_name(last_name)
       when not is_binary(last_name),
       do: @err_invalid_last_name

  defp validate_last_name(_), do: :ok

  defp validate_search_type(search_type)
       when search_type in [:email, :phone, :email_and_phone],
       do: :ok

  defp validate_search_type(_), do: @err_invalid_search_type

  defp validate_company_domain(nil), do: :ok
  defp validate_company_domain(""), do: :ok

  defp validate_company_domain(domain) do
    case DomainValidator.valid_domain?(domain) do
      true -> :ok
      false -> @err_invalid_domain
    end
  end

  defp validate_has_company_name_or_domain(company_name, domain) do
    case {company_name_empty?(company_name), company_domain_empty?(domain)} do
      {true, true} -> @err_company_details_empty
      _ -> :ok
    end
  end

  defp company_name_empty?(nil), do: true
  defp company_name_empty?(""), do: true

  defp company_name_empty?(company_name)
       when is_binary(company_name),
       do: false

  defp company_name_empty?(_), do: true

  defp company_domain_empty?(nil), do: true
  defp company_domain_empty?(""), do: true

  defp company_domain_empty?(domain)
       when is_binary(domain),
       do: false

  defp company_domain_empty?(_), do: true
end
