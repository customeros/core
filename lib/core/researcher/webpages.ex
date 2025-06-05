defmodule Core.Researcher.Webpages do
  @moduledoc """
  Database operations for scraped webpages.
  """
  require OpenTelemetry.Tracer
  alias Core.Repo
  alias Core.Researcher.Webpages.ScrapedWebpage
  alias Core.Researcher.Webpages.Classification
  alias Core.Researcher.Webpages.Intent
  alias Core.Utils.DomainExtractor
  import Ecto.Query

  ## Insert with ignore on conflict duplicate url ##
  def save_scraped_content(
        url,
        content,
        links,
        summary \\ nil
      ) do
    case DomainExtractor.extract_base_domain(url) do
      {:ok, domain} ->
        attrs =
          %{
            url: url,
            domain: domain,
            content: content,
            links: links,
            summary: summary
          }

        changeset =
          %ScrapedWebpage{}
          |> ScrapedWebpage.changeset(attrs)

        case Repo.insert(changeset,
               on_conflict: :nothing,
               conflict_target: :url
             ) do
          {:ok, %ScrapedWebpage{} = webpage} ->
            {:ok, webpage}

          {:ok, nil} ->
            case get_by_url(url) do
              {:ok, existing} -> {:ok, existing}
              _ -> {:error, :not_found}
            end

          {:error, changeset} ->
            {:error, changeset}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Update ##
  def update_classification(url, %Classification{} = classification) do
    case get_by_url(url) do
      {:error, :not_found} ->
        {:error, :not_found}

      # Fixed: was missing {:ok, ...} pattern
      {:ok, webpage} ->
        attrs = build_classification_attrs(classification)

        webpage
        |> ScrapedWebpage.changeset(attrs)
        |> Repo.update()
    end
  end

  def update_intent(url, %Intent{} = intent) do
    case get_by_url(url) do
      {:error, :not_found} ->
        {:error, :not_found}

      # Fixed: was missing {:ok, ...} pattern
      {:ok, webpage} ->
        attrs = build_intent_attrs(intent)

        webpage
        |> ScrapedWebpage.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Update both classification and intent fields in a single transaction.
  Either parameter can be nil to skip that update.
  """
  def update_classification_and_intent(
        url,
        classification \\ nil,
        intent \\ nil
      ) do
    case get_by_url(url) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, webpage} ->
        attrs =
          %{}
          |> maybe_add_classification(classification)
          |> maybe_add_intent(intent)

        if attrs == %{} do
          # No updates needed
          {:ok, webpage}
        else
          webpage
          |> ScrapedWebpage.changeset(attrs)
          |> Repo.update()
        end
    end
  end

  @doc """
  Update a webpage with arbitrary attributes.
  Useful for updating any fields on the schema.
  """
  def update_webpage(url, attrs) when is_map(attrs) do
    case get_by_url(url) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, webpage} ->
        webpage
        |> ScrapedWebpage.changeset(attrs)
        |> Repo.update()
    end
  end

  ## Get ##
  def get_by_url(url) do
    OpenTelemetry.Tracer.with_span "scraped_webpages.get_by_url" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      case Repo.get_by(ScrapedWebpage, url: url) do
        %ScrapedWebpage{} = webpage ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", "found"}
          ])

          {:ok, webpage}

        nil ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", "not_found"}
          ])

          {:error, :not_found}
      end
    end
  end

  def list_by_domain(domain) do
    # Fixed: Repo.all returns a list, not a single record
    pages = Repo.all(from s in ScrapedWebpage, where: s.domain == ^domain)

    case pages do
      [] -> {:error, :not_found}
      pages -> {:ok, pages}
    end
  end

  @spec get_business_pages_by_domain(String.t(), keyword()) ::
          {:ok, [ScrapedWebpage.t()]} | {:error, :no_business_pages_found}
  def get_business_pages_by_domain(domain, opts \\ []) do
    OpenTelemetry.Tracer.with_span "scraped_webpages.get_business_pages_by_domain" do
      OpenTelemetry.Tracer.set_attributes([
        {"domain", domain}
      ])

      limit = Keyword.get(opts, :limit)

      content_types =
        Keyword.get(opts, :content_types, [
          "product_page",
          "solution_page",
          "case_study"
        ])

      case domain
           |> business_pages_query(content_types)
           |> maybe_limit(limit)
           |> Repo.all() do
        [] ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", "not_found"}
          ])

          {:error, :no_business_pages_found}

        pages ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", "found"},
            {"result.pages.found", length(pages)}
          ])

          {:ok, pages}
      end
    end
  end

  # Private helper functions

  defp business_pages_query(domain, content_types) do
    from w in ScrapedWebpage,
      where: w.domain == ^domain,
      where: w.content_type in ^content_types,
      order_by: [desc: w.inserted_at]
  end

  ## Helpers ##

  defp maybe_add_classification(attrs, nil) do
    attrs
  end

  defp maybe_add_classification(attrs, %Classification{} = classification) do
    classification_attrs = build_classification_attrs(classification)
    Map.merge(attrs, classification_attrs)
  end

  defp maybe_add_intent(attrs, nil) do
    attrs
  end

  defp maybe_add_intent(attrs, %Intent{} = intent) do
    intent_attrs = build_intent_attrs(intent)
    Map.merge(attrs, intent_attrs)
  end

  defp build_classification_attrs(%Classification{} = classification) do
    content_type_string =
      case classification.content_type do
        atom when is_atom(atom) -> Atom.to_string(atom)
        string when is_binary(string) -> string
        nil -> nil
      end

    %{
      primary_topic: classification.primary_topic,
      secondary_topics: classification.secondary_topics || [],
      solution_focus: classification.solution_focus || [],
      content_type: content_type_string,
      industry_vertical: classification.industry_vertical,
      key_pain_points: classification.key_pain_points || [],
      value_proposition: classification.value_proposition,
      referenced_customers: classification.referenced_customers || []
    }
  end

  defp build_intent_attrs(%Intent{} = intent) do
    %{
      problem_recognition_score: intent.problem_recognition,
      solution_research_score: intent.solution_research,
      evaluation_score: intent.evaluation,
      purchase_readiness_score: intent.purchase_readiness
    }
  end

  defp maybe_limit(query, nil), do: query

  defp maybe_limit(query, limit) when is_integer(limit) and limit > 0 do
    limit(query, ^limit)
  end

  defp maybe_limit(query, _), do: query
end
