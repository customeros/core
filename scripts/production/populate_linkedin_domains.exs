Application.ensure_all_started(:core)

alias Core.Repo
alias Core.ScrapinCompany
alias Core.Utils.DomainExtractor
require Logger

import Ecto.Query

defmodule LinkedinDomainPopulator do
  def run_all(limit \\ 10, from_date \\ ~U[2025-01-01 00:00:00Z]) do
    Logger.info("Starting to populate linkedin_domain for all ScrapinCompany records from #{from_date}")

    case get_records_without_linkedin_domain(limit, from_date) do
      {:error, :not_found} ->
        Logger.info("No ScrapinCompany records found with null linkedin_domain from #{from_date}")

      {:ok, records} ->
        Logger.info("Found #{length(records)} records to process")

        records
        |> Enum.with_index(1)
        |> Enum.each(fn {record, index} ->
          Logger.info("[#{index}/#{length(records)}] Processing record: #{record.id}")
          process_record(record)
        end)

        Logger.info("Completed processing all records")
    end
  end



  defp get_records_without_linkedin_domain(limit, from_date) do
    records =
      ScrapinCompany
      |> where([s], is_nil(s.linkedin_domain))
      |> where([s], s.company_found == true)
      |> where([s], s.success == true)
      |> where([s], s.inserted_at >= ^from_date)
      |> order_by([s], asc: s.inserted_at)
      |> limit(^limit)
      |> Repo.all()

    case records do
      [] -> {:error, :not_found}
      records -> {:ok, records}
    end
  end

  defp process_record(%ScrapinCompany{} = record) do
    case extract_website_url_from_data(record.data) do
      {:ok, website_url} when is_binary(website_url) ->
        case DomainExtractor.extract_base_domain(website_url) do
          {:ok, linkedin_domain} when is_binary(linkedin_domain) ->
            update_record_with_linkedin_domain(record, linkedin_domain)

          {:error, reason} ->
            Logger.warning("Failed to extract domain from website URL", %{
              record_id: record.id,
              website_url: website_url,
              reason: reason
            })

          _ ->
            Logger.warning("No domain extracted from website URL", %{
              record_id: record.id,
              website_url: website_url
            })
        end

      {:ok, nil} ->
        Logger.warning("No website URL found in record data", %{
          record_id: record.id
        })

      {:error, reason} ->
        Logger.error("Failed to extract website URL from record data", %{
          record_id: record.id,
          reason: reason
        })
    end
  end

  defp extract_website_url_from_data(data) when is_binary(data) do
    case Jason.decode(data, keys: :atoms) do
      {:ok, decoded_data} ->
        case decoded_data do
          %{company: company_data} when is_map(company_data) ->
            website_url =
              Map.get(company_data, :website_url) ||
                Map.get(company_data, :websiteUrl)

            {:ok, website_url}

          _ ->
            {:error, :no_company_data}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_website_url_from_data(_), do: {:error, :invalid_data}

  defp update_record_with_linkedin_domain(record, linkedin_domain) do
    case Repo.update_all(
           from(s in ScrapinCompany, where: s.id == ^record.id),
           set: [linkedin_domain: linkedin_domain]
         ) do
      {1, _} ->
        Logger.info("Successfully updated linkedin_domain", %{
          record_id: record.id,
          linkedin_domain: linkedin_domain
        })

      {0, _} ->
        Logger.error("Failed to update record - no rows affected", %{
          record_id: record.id,
          linkedin_domain: linkedin_domain
        })

      _ ->
        Logger.error("Unexpected result when updating record", %{
          record_id: record.id,
          linkedin_domain: linkedin_domain
        })
    end
  end
end

# Run the script
LinkedinDomainPopulator.run_all(1000, ~U[2025-06-20 08:32:30])
