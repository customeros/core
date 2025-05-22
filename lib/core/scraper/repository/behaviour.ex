defmodule Core.Scraper.Repository.Behaviour do
  @moduledoc """
  Behaviour module defining the contract for the scraper repository.
  """

  @type url :: String.t()
  @type content :: String.t()
  @type links :: list(String.t())
  @type classification :: map() | nil
  @type intent :: map() | nil

  @callback get_by_url(url()) :: map() | nil
  @callback save_scraped_content(url(), content(), links(), classification(), intent()) :: {:ok, map()} | {:error, term()}
  @callback delete_all() :: :ok
end
