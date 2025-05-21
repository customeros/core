defmodule Core.Scraper.Service do
  alias Task
  use GenServer
  
  @name __MODULE__  
  @timeout 300_000  # 5 minutes in milliseconds
  
  def start_link(opts \\ []) do
    opts = Keyword.merge([name: @name], opts)
    GenServer.start_link(__MODULE__, %{}, opts)
  end
  
  def crawl_website(domain, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @timeout)
    GenServer.call(@name, {:crawl_website, domain, opts}, timeout)
  end
  
  @impl true
  def init(state) do
    {:ok, state}
  end
  
  @impl true
  def handle_call({:crawl_website, domain, opts}, _from, state) do
    task = Task.async(fn -> Core.Scraper.Crawler.start(domain, opts) end)
    result = Task.await(task, @timeout)
    {:reply, result, state}
  end
end
