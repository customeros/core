defmodule Core.Scraper.Repository do
  @moduledoc """
  Database operations for scraped webpages.
  """

  @callback get_by_url(url :: String.t()) :: nil | %Core.Scraper.ScrapedWebpage{}
  @callback save_scraped_content(url :: String.t(), content :: String.t(), links :: list(String.t()), classification :: nil | %Core.Ai.Webpage.Classification{}, intent :: nil | %Core.Ai.Webpage.Intent{}) :: {:ok, %Core.Scraper.ScrapedWebpage{}} | {:error, term()}

  alias Core.Repo
  alias Core.Scraper.ScrapedWebpage
  alias Core.Ai.Webpage.Classification
  alias Core.Ai.Webpage.Intent
  import Ecto.Query

  def save_scraped_content(
        url,
        content,
        links,
        classification \\ nil,
        intent \\ nil
      ) do
    domain = extract_domain(url)

    attrs =
      %{
        url: url,
        domain: domain,
        content: content,
        links: links
      }
      |> maybe_add_classification(classification)
      |> maybe_add_intent(intent)

    # Debug: Let's see the final attributes
    IO.inspect(attrs, label: "Final attributes")

    changeset =
      %ScrapedWebpage{}
      |> ScrapedWebpage.changeset(attrs)

    Repo.insert(changeset)
  end

  def save_full_scraped_data(url, %{
        content: content,
        classification: classification,
        intent: intent,
        links: links
      }) do
    save_scraped_content(url, content, links, classification, intent)
  end

  def update_classification(url, %Classification{} = classification) do
    case get_by_url(url) do
      nil ->
        {:error, :not_found}

      webpage ->
        attrs = build_classification_attrs(classification)

        webpage
        |> ScrapedWebpage.changeset(attrs)
        |> Repo.update()
    end
  end

  # Fixed: was Intent
  def update_intent(url, %Intent{} = intent) do
    case get_by_url(url) do
      nil ->
        {:error, :not_found}

      webpage ->
        attrs = build_intent_attrs(intent)

        webpage
        |> ScrapedWebpage.changeset(attrs)
        |> Repo.update()
    end
  end

  def get_by_url(url) do
    Repo.get_by(ScrapedWebpage, url: url)
  end

  def list_by_domain(domain) do
    Repo.all(from s in ScrapedWebpage, where: s.domain == ^domain)
  end

  def delete_all do
    Repo.delete_all(ScrapedWebpage)
  end

  # Private helper functions
  defp extract_domain(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> url
    end
  end

  defp maybe_add_classification(attrs, nil) do
    IO.puts("Classification is nil")
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
end
