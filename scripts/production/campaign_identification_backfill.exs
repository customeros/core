#!/usr/bin/env elixir

# Campaign Identification Backfill Script
# 
# This script streams through all sessions in the database and calls
# CampaignIdentifier.identify_campaigns/1 for each session to backfill
# campaign data that may have been missed during initial processing.
#
# Usage:
#   mix run scripts/production/campaign_identification_backfill.exs

require Logger

alias Core.Repo
alias Core.WebTracker.Sessions.Session
alias Core.WebTracker.SessionAnalyzer.CampaignIdentifier

import Ecto.Query

defmodule CampaignBackfillScript do
  @batch_size 100
  @log_interval 500

  def run do
    Logger.info("Starting campaign identification backfill...")
    
    start_time = System.monotonic_time(:millisecond)
    
    # Get total count for progress tracking
    total_sessions = get_total_session_count()
    Logger.info("Total sessions to process: #{total_sessions}")
    
    # Stream and process sessions in batches
    {processed_count, success_count, error_count} = stream_and_process_sessions()
    
    end_time = System.monotonic_time(:millisecond)
    duration_ms = end_time - start_time
    duration_seconds = duration_ms / 1000
    
    Logger.info("""
    Campaign identification backfill completed!
    
    Summary:
    - Total processed: #{processed_count}
    - Successful: #{success_count}
    - Errors: #{error_count}
    - Duration: #{Float.round(duration_seconds, 2)} seconds
    - Rate: #{Float.round(processed_count / duration_seconds, 2)} sessions/second
    """)
  end

  defp get_total_session_count do
    from(s in Session, select: count(s.id))
    |> Repo.one()
  end

  defp stream_and_process_sessions do
    query = from(s in Session, select: s.id, order_by: [asc: s.id])
    
    Repo.stream(query, max_rows: @batch_size)
    |> Stream.with_index(1)
    |> Enum.reduce({0, 0, 0}, fn {session_id, index}, {processed, success, errors} ->
      result = process_session(session_id)
      
      new_processed = processed + 1
      {new_success, new_errors} = case result do
        :ok -> {success + 1, errors}
        :error -> {success, errors + 1}
      end
      
      # Log progress periodically
      if rem(index, @log_interval) == 0 do
        Logger.info("Processed #{new_processed} sessions (#{new_success} success, #{new_errors} errors)")
      end
      
      {new_processed, new_success, new_errors}
    end)
  end

  defp process_session(session_id) do
    case CampaignIdentifier.identify_campaigns(session_id) do
      {:ok, _session} ->
        :ok
        
      {:error, reason} ->
        Logger.warning(
          "Failed to identify campaigns for session #{session_id}: #{inspect(reason)}"
        )
        :error
    end
  rescue
    error ->
      Logger.error(
        "Exception while processing session #{session_id}: #{inspect(error)}"
      )
      :error
  end
end

# Check if we're in a transaction (running under Repo.transaction)
# If not, wrap the execution in a transaction for safety
case Process.get(:ecto_transaction_pid) do
  nil ->
    Repo.transaction(fn ->
      CampaignBackfillScript.run()
    end, timeout: :infinity)
    
  _pid ->
    # Already in transaction, run directly
    CampaignBackfillScript.run()
end
