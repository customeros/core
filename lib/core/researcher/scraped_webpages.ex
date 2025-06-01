defmodule Core.Researcher.ScrapedWebpages do
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

  ## Create ##
  def save_scraped_content(
        url,
        content,
        links,
        classification \\ nil,
        intent \\ nil,
        summary \\ nil
      ) do
    with {:ok, domain} <- DomainExtractor.extract_base_domain(url) do
      attrs =
        %{
          url: url,
          domain: domain,
          content: content,
          links: links,
          summary: summary
        }
        |> maybe_add_classification(classification)
        |> maybe_add_intent(intent)

      changeset =
        %ScrapedWebpage{}
        |> ScrapedWebpage.changeset(attrs)

      Repo.insert(changeset)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def save_full_scraped_data(url, %{
        content: content,
        classification: classification,
        intent: intent,
        links: links
      }) do
    save_scraped_content(url, content, links, classification, intent)
  end

  ## Update ##
  def update_classification(url, %Classification{} = classification) do
    case get_by_url(url) do
      {:error, :not_found} ->
        {:error, :not_found}

      webpage ->
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

      webpage ->
        attrs = build_intent_attrs(intent)

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
    case Repo.all(from s in ScrapedWebpage, where: s.domain == ^domain) do
      %ScrapedWebpage{} = webpage -> {:ok, webpage}
      nil -> {:error, :not_found}
    end
  end

  @spec get_business_pages_by_domain(String.t(), keyword()) ::
          {:ok, [ScrapedWebpage.t()]} | {:error, :not_found}

  def get_business_pages_by_domain(domain, opts \\ []) do
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
      [] -> {:error, :not_found}
      pages -> {:ok, pages}
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
