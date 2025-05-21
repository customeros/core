defmodule Core.Icp.BuildProfile do

  def start(domain) do
    IO.puts("building ICP Profile for #{domain}")
    dbg(Core.Scraper.Crawl.start(domain))
  end
  
end
