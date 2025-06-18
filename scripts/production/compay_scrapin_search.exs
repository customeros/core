Application.ensure_all_started(:core)

alias Core.Repo
alias Core.ScrapinCompany
alias Core.Utils.IdGenerator
require Logger

# --- Openline Repo and Schema ---
defmodule OpenlineRepo do
  use Ecto.Repo, otp_app: :core, adapter: Ecto.Adapters.Postgres
end

defmodule EnrichDetailsScrapin do
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: false}
  schema "enrich_details_scrapin" do
    field :flow, :string
    field :param1, :string
    field :data, :string
    field :ported, :boolean
    field :success, :boolean
    field :company_found, :boolean
    field :created_at, :utc_datetime
    field :updated_at, :utc_datetime
    # ... other fields omitted for brevity
  end
end

# --- Configure OpenlineRepo ---
# You may want to use ENV vars in production. For now, hardcode for script use.
openline_db_url =
  System.get_env("OPENLINE_DB_URL") ||
    "ecto://postgres:postgres@localhost/openline"

Application.put_env(:core, OpenlineRepo, url: openline_db_url, pool_size: 2)
{:ok, _} = OpenlineRepo.start_link()

import Ecto.Query

defmodule ScrapinCompanyMigrator do
  import Ecto.Query

  def run(quantity \\ 1) do
    quantity =
      case quantity do
        n when is_binary(n) ->
          case Integer.parse(n) do
            {int, _} when int > 0 -> int
            _ -> 1
          end
        n when is_integer(n) and n > 0 -> n
        _ -> 1
      end

    source_records =
      EnrichDetailsScrapin
      |> where([e], e.flow == "COMPANY_SEARCH" and e.success == true and e.company_found == true and (is_nil(e.ported) or e.ported == false))
      |> order_by([e], desc: e.created_at)
      |> limit(^quantity)
      |> OpenlineRepo.all()

    Enum.each(source_records, fn record ->
      param1 = record.param1

      exists =
        ScrapinCompany
        |> where([s], s.request_param == ^param1)
        |> Repo.exists?()

      if exists do
        # Mark as ported in source
        OpenlineRepo.update_all(
          from(e in EnrichDetailsScrapin, where: e.id == ^record.id),
          set: [ported: true]
        )
      else
        case Jason.decode(record.data) do
          {:ok, data_map} ->
            company_map = data_map["company"] || %{}
            website_url = company_map["websiteUrl"]
            domain_for_check = case Core.Utils.DomainExtractor.extract_base_domain(website_url) do
              {:ok, domain} -> domain
              _ -> website_url
            end
            domain =
              case Core.Utils.PrimaryDomainFinder.get_primary_domain(domain_for_check) do
                {:ok, d} when is_binary(d) ->
                  d
                _result ->
                  nil
              end
            attrs = %{
              id: IdGenerator.generate_id_21(Core.ScrapinCompany.id_prefix()),
              linkedin_id: company_map["linkedInId"],
              linkedin_alias: company_map["universalName"],
              domain: domain,
              request_param: param1,
              data: record.data,
              success: true,
              company_found: true
            }
            %ScrapinCompany{}
            |> ScrapinCompany.changeset(attrs)
            |> Repo.insert()

            OpenlineRepo.update_all(
              from(e in EnrichDetailsScrapin, where: e.id == ^record.id),
              set: [ported: true, updated_at: DateTime.utc_now()]
            )
          _ ->
            # If data is invalid, still mark as ported
            Logger.error("Invalid data for record #{record.id}")
            OpenlineRepo.update_all(
              from(e in EnrichDetailsScrapin, where: e.id == ^record.id),
              set: [ported: true, updated_at: DateTime.utc_now()]
            )
        end
      end
    end)

    IO.puts("Migration complete. Processed #{length(source_records)} record(s).")
  end
end

# Parse quantity from command line args, default to 1
quantity =
  case System.argv() do
    [arg | _] -> arg
    _ -> 1
  end

ScrapinCompanyMigrator.run(quantity)
