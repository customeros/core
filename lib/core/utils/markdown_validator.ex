defmodule Core.Utils.MarkdownValidator do
  @moduledoc """
  Validates markdown text and removes emojis.
  """

  require Logger

  # Error constants
  @err_invalid_text {:error, "Markdown must be text"}
  @err_invalid_list_formatting {:error, "Invalid list formatting"}
  @err_invalid_link_syntax {:error, "Invalid link syntax"}
  @err_unbalanced_brackets {:error, "Unbalanced brackets"}
  @err_unmatched_emphasis {:error, "Unmatched emphasis"}
  @err_processing_failed {:error, "Failed to process text"}

  @emoji_pattern ~r/[\x{1F600}-\x{1F64F}]|[\x{1F300}-\x{1F5FF}]|[\x{1F680}-\x{1F6FF}]|[\x{1F1E0}-\x{1F1FF}]|[\x{2600}-\x{26FF}]|[\x{2700}-\x{27BF}]|[\x{1F900}-\x{1F9FF}]|[\x{1F018}-\x{1F270}]|[\x{238C}-\x{2454}]|[\x{20D0}-\x{20FF}]|[\x{FE00}-\x{FE0F}]|[\x{1F000}-\x{1F02F}]|[\x{1F0A0}-\x{1F0FF}]/u

  @doc """
  Validates markdown syntax and removes all emojis from the text.
  """
  def validate_and_clean(text) when is_binary(text) do
    with {:ok, clean_text} <- remove_emojis(text),
         :ok <- validate_markdown(clean_text) do
      {:ok, clean_text}
    end
  end

  def validate_and_clean(_), do: @err_invalid_text

  @doc """
  Removes all emojis from the given text.
  """
  def remove_emojis(text) do
    cleaned_text = Regex.replace(@emoji_pattern, text, "")
    {:ok, cleaned_text}
  rescue
    reason ->
      Logger.error("Cleaning emoji's failed: #{reason}")
      @err_processing_failed
  end

  @doc """
  Validates basic markdown syntax including links, emphasis, and lists.
  """
  def validate_markdown(text) do
    with :ok <- validate_links(text),
         :ok <- validate_emphasis(text),
         :ok <- validate_lists(text) do
      :ok
    end
  end

  defp validate_links(text) do
    if balanced_brackets?(text, "[", "]") and balanced_brackets?(text, "(", ")") do
      has_orphaned_brackets =
        (String.contains?(text, "](") and
           not String.match?(text, ~r/\[[^\]]*\]\([^)]*\)/)) or
          String.match?(text, ~r/\][^(]/) or
          String.match?(text, ~r/\[[^\]]*\]$/)

      if has_orphaned_brackets do
        @err_invalid_link_syntax
      else
        :ok
      end
    else
      @err_unbalanced_brackets
    end
  end

  # Validates emphasis markers (* and _) are balanced
  defp validate_emphasis(text) do
    star_count = count_char(text, "*")
    underscore_count = count_char(text, "_")

    if rem(star_count, 2) == 0 and rem(underscore_count, 2) == 0 do
      :ok
    else
      @err_unmatched_emphasis
    end
  end

  # Validates list formatting (checks for empty list items)
  defp validate_lists(text) do
    invalid_lists =
      text
      |> String.split(~r/\n/)
      |> Enum.any?(&String.match?(&1, ~r/^\s*[-*+]\s*$/))

    if invalid_lists do
      @err_invalid_list_formatting
    else
      :ok
    end
  end

  # Checks if brackets are balanced in the text
  defp balanced_brackets?(text, open_char, close_char) do
    text
    |> String.graphemes()
    |> Enum.reduce_while({0, true}, fn
      ^open_char, {count, true} -> {:cont, {count + 1, true}}
      ^close_char, {count, true} when count > 0 -> {:cont, {count - 1, true}}
      ^close_char, {0, true} -> {:halt, {0, false}}
      _, acc -> {:cont, acc}
    end)
    |> case do
      {0, true} -> true
      _ -> false
    end
  end

  # Helper function to count occurrences of a character
  defp count_char(text, char) do
    text
    |> String.graphemes()
    |> Enum.count(&(&1 == char))
  end

  @doc """
  Convenience function that removes emojis without validation.
  Returns the cleaned text directly or the original text if processing fails.
  """
  def clean_emojis(text) when is_binary(text) do
    case remove_emojis(text) do
      {:ok, cleaned} -> cleaned
      {:error, _} -> text
    end
  end

  def clean_emojis(_), do: ""
end
