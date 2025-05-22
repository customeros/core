defmodule Core.Utils.UrlExpander do
  @doc """
  Expands shortened URLs to their full domain.
  Returns {expanded_domain, was_expanded}.
  """
    def expand_short_url(domain) do
  url_shorteners = [
    "bit.ly/",
    "hubs.ly/"
  ]

  shortener_found =
    Enum.any?(url_shorteners, fn shortener ->
      String.contains?(domain, shortener)
    end)

  if shortener_found do
    {is_primary, expanded_domain} = Core.Utils.PrimaryDomain.primary_domain_check(domain)
    
    if is_primary && expanded_domain != "" do
      {expanded_domain, true}
    else
      {domain, false}
    end
  else
    {domain, false}
  end
end

end
