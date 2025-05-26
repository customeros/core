defmodule Core.Scraper.Repository.Behaviour do
  @moduledoc """
  Behaviour for the scraper repository.
  """

  @callback get_by_url(url :: String.t()) :: {:ok, map()} | nil
  @callback save_scraped_content(
              url :: String.t(),
              content :: String.t(),
              links :: [String.t()],
              classification :: map() | nil,
              intent :: map() | nil
            ) :: {:ok, map()} | {:error, term()}
end
