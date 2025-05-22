defmodule Core.WebTracker.IPIntelligenceBehaviour do
  @moduledoc """
  Behaviour for IP intelligence gathering and validation.
  """

  @callback get_ip_data(String.t()) :: {:ok, map()} | {:error, term()}
  @callback get_company_info(String.t()) :: {:ok, map()} | {:error, term()}
end
