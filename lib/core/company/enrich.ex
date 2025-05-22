defmodule Core.Company.Enrich do
  use GenServer
  require Logger
  import Ecto.Query

  alias Core.Repo
  alias Core.Company.Schemas.Company

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Triggers industry enrichment for a company by ID.
  Returns immediately while processing happens asynchronously.
  """
  @spec enrich_industry(integer()) :: :ok
  def enrich_industry(company_id) when is_integer(company_id) do
    GenServer.cast(__MODULE__, {:enrich_industry, company_id})
  end

  def enrich_industry(_), do: {:error, :invalid_company_id}

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:enrich_industry, company_id}, state) do
    Task.start(fn -> process_industry_enrichment(company_id) end)
    {:noreply, state}
  end

  # Private Functions

  defp process_industry_enrichment(company_id) do
    case Repo.get(Company, company_id) do
      nil ->
        Logger.warning("Company not found for industry enrichment", %{company_id: company_id})

      company ->
        if should_enrich_industry?(company) do
          # Safely update only the industry_enrich_attempt_at field
          {count, _} = Repo.update_all(
            from(c in Company, where: c.id == ^company_id),
            set: [industry_enrich_attempt_at: DateTime.utc_now()]
          )

          if count > 0 do
            Logger.debug("Marked industry enrichment attempt", %{company_id: company_id})
          else
            Logger.error("Failed to mark industry enrichment attempt - company not found", %{
              company_id: company_id
            })
          end

          # TODO: Implement industry code enrichment logic here
          # This will involve:
          # 1. Analyzing scraped_content
          # 2. Determining appropriate industry code (using Snitcher)
          # 3. Updating company with industry code
          # 4. Creating a lead for the company

        else
          Logger.info("Skipping industry enrichment", %{
            company_id: company_id,
            reason: enrichment_skip_reason(company)
          })
        end
    end
  end

  defp should_enrich_industry?(company) do
    cond do
      not is_nil(company.industry_code) ->
        false

      is_nil(company.scraped_content) or company.scraped_content == "" ->
        false

      true ->
        true
    end
  end

  defp enrichment_skip_reason(company) do
    cond do
      not is_nil(company.industry_code) ->
        "industry_code already set"

      is_nil(company.scraped_content) or company.scraped_content == "" ->
        "no scraped content available"

      true ->
        "unknown"
    end
  end
end
