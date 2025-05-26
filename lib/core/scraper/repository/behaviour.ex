defmodule Core.Scraper.Repository.Behaviour do
  @moduledoc """
  Behaviour for the Scraper Repository.
  """

  @callback save_scraped_content(
              url :: String.t(),
              content :: String.t(),
              links :: [String.t()],
              classification :: map() | nil,
              intent :: map() | nil,
              summary :: String.t() | nil
            ) :: {:ok, map()} | {:error, term()}

  @callback get_by_url(url :: String.t()) :: {:ok, map()} | {:error, :not_found}
  @callback list_by_domain(domain :: String.t()) :: {:ok, [map()]} | {:error, :not_found}
  @callback get_business_pages_by_domain(domain :: String.t(), opts :: keyword()) ::
              {:ok, [map()]} | {:error, :not_found}
end
