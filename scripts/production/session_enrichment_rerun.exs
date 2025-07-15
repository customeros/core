Application.ensure_all_started(:core)

defmodule RerunSessionEnrichment do
  

  def run(path, limit \\ nil) do
    stream = path
    |> File.stream!()
    |> CSV.decode(headers: true)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Stream.map(&elem(&1, 1))
    
    stream = if limit, do: Stream.take(stream, limit), else: stream
    
    stream
    |> Stream.with_index(1)  
    |> Stream.each(fn {row, index} ->
      Core.WebTracker.CompanyEnricher.enrich_session(row["id"])
      IO.puts("Processing record #{index}")
      Process.sleep(500)
    end)
    |> Stream.run()  
  end
end

RerunSessionEnrichment.run("/Users/mbrown/Downloads/rerun_sessions.csv")
