defmodule Core.Researcher.Webpages.Cleaner do
  @moduledoc """
  Processes and cleans markdown content from webpages.

  This module handles:
  * Removing navigation sections and elements
  * Cleaning up link-heavy sections
  * Processing document sections and headings
  * Filtering out navigation markers
  * Managing document structure and formatting

  It uses a sophisticated approach to identify and remove
  navigation elements, lists, and other non-content elements
  while preserving the meaningful content of webpages.
  The module processes content in sections to maintain
  document structure and readability.
  """

  defmodule DocumentSection do
    @moduledoc """
    Represents a section of a document with its heading and content.
    """
    defstruct heading: "",
              content: [],
              link_count: 0,
              text_count: 0,
              list_count: 0
  end

  def process_markdown_webpage(markdown_content) do
    markdown_content
    |> remove_navigation_sections()
    |> remove_navigation_elements()
    |> format_output()
  end

  defp remove_navigation_sections(text) do
    lines = String.split(text, "\n")

    # First pass: parse into sections and remove link-heavy ones
    sections =
      lines
      |> parse_document_sections()
      |> remove_navigation_heavy_sections()

    # Second pass: remove list-heavy sections and navigation markers
    sections
    |> remove_lists_and_navigation_markers()
    |> render_document()
  end

  defp parse_document_sections(lines) do
    {sections, current} =
      Enum.reduce(lines, {[], %DocumentSection{}}, fn line,
                                                      {sections, current} ->
        if heading?(line) || horizontal_rule?(line) do
          # Save previous section if it exists
          sections =
            if current.heading != "" || length(current.content) > 0 do
              [current | sections]
            else
              sections
            end

          # Start a new section
          {sections, %DocumentSection{heading: line}}
        else
          # Analyze line content
          trimmed_line = String.trim(line)

          current =
            cond do
              markdown_link?(line) || html_link?(line) ||
                  link_definition?(line) ->
                %{
                  current
                  | link_count: current.link_count + 1,
                    content: current.content ++ [line]
                }

              link_list_item?(line) ->
                %{
                  current
                  | list_count: current.list_count + 1,
                    content: current.content ++ [line]
                }

              String.length(trimmed_line) > 0 ->
                %{
                  current
                  | text_count: current.text_count + 1,
                    content: current.content ++ [line]
                }

              true ->
                %{current | content: current.content ++ [line]}
            end

          {sections, current}
        end
      end)

    # Add the final section
    sections =
      if current.heading != "" || length(current.content) > 0 do
        [current | sections]
      else
        sections
      end

    # Reverse to maintain original order
    Enum.reverse(sections)
  end

  defp remove_navigation_heavy_sections(sections) do
    Enum.filter(sections, fn section ->
      section.link_count <= section.text_count
    end)
  end

  defp remove_lists_and_navigation_markers(sections) do
    Enum.reduce(sections, [], fn section, result ->
      # Skip list-heavy sections
      is_list_heavy =
        section.list_count > 0 &&
          (section.text_count == 0 ||
             section.list_count > section.text_count * 3)

      if is_list_heavy do
        result
      else
        # Filter out navigation markers from content
        clean_content =
          Enum.reject(section.content, fn line ->
            navigation_marker?(line) || link_section?(line) ||
              link_list_item?(line)
          end)

        # Only keep sections with content after cleaning
        if section.heading != "" || length(clean_content) > 0 do
          clean_section = %{section | content: clean_content}
          [clean_section | result]
        else
          result
        end
      end
    end)
    |> Enum.reverse()
  end

  defp render_document(sections) do
    lines =
      Enum.flat_map(sections, fn section ->
        if section.heading != "" do
          [section.heading | section.content]
        else
          section.content
        end
      end)

    Enum.join(lines, "\n")
  end

  # Helper functions to identify different elements

  defp heading?(line) do
    heading_regex = ~r/^\#{1,6}\s+.+$|^.+\n[=\-]+$/
    Regex.match?(heading_regex, line)
  end

  defp horizontal_rule?(line) do
    hr_regex = ~r/^(\*{3,}|-{3,}|_{3,})$/
    Regex.match?(hr_regex, String.trim(line))
  end

  defp markdown_link?(line) do
    link_regex = ~r/\[([^\]]+)\]\([^)]+\)/
    Regex.match?(link_regex, line)
  end

  defp html_link?(line) do
    html_link_regex = ~r/<a\s+[^>]*>[^<]*<\/a>/
    Regex.match?(html_link_regex, line)
  end

  defp link_definition?(line) do
    link_def_regex = ~r/^\s*\[[^\]]+\]:\s*http.+$/
    Regex.match?(link_def_regex, line)
  end

  defp link_list_item?(line) do
    link_list_item_regex =
      ~r/^\s*[\*\-+]\s+\[.+\]\(.+\).*$|^\s*\d+\.\s+\[.+\]\(.+\).*$/

    Regex.match?(link_list_item_regex, line)
  end

  defp navigation_marker?(line) do
    nav_markers = [
      "Navigation",
      "Menu",
      "Links",
      "Buttons",
      "Toggle navigation",
      "Copyright",
      "All rights reserved",
      "Follow us on",
      "Find us on",
      "Links/Buttons:",
      "Social media",
      "Back to",
      "Skip to"
    ]

    lowered = String.downcase(line)

    Enum.any?(nav_markers, fn marker ->
      String.contains?(lowered, String.downcase(marker))
    end)
  end

  defp link_section?(line) do
    link_section_regex = ~r/^(Links|Nav|Menu|Navigation|Footer)(\W|$)/
    Regex.match?(link_section_regex, String.trim(line))
  end

  defp remove_navigation_elements(text) do
    # Patterns to identify and remove
    patterns = [
      # Links - only remove if they're a list of links with no surrounding context
      # List item links
      ~r/(?m)^\s*\* \[[^\]]+\]\([^)]+\)\s*$/,
      # List item links with dash
      ~r/(?m)^\s*- \[[^\]]+\]\([^)]+\)\s*$/,
      # List item links with plus
      ~r/(?m)^\s*\+ \[[^\]]+\]\([^)]+\)\s*$/,

      # Navigation lines and sections
      # Bootstrap toggle nav
      ~r/(?i)toggle navigation/,
      # Copyright notices
      ~r/(?i)copyright ©\d{4}.*/,
      # Rights reserved
      ~r/(?i)all rights reserved.*/,
      # Social media sections
      ~r/(?i)(follow us on|find us on).*/,
      # Links section headers
      ~r/(?m)^Links\/Buttons:$.*?^$/
    ]

    # Apply each pattern
    Enum.reduce(patterns, text, fn pattern, text ->
      Regex.replace(pattern, text, "")
    end)
  end

  defp format_output(text) do
    # Clean up excessive blank lines (more than 2 consecutive)
    text = Regex.replace(~r/\n{3,}/, text, "\n\n")

    # Fix spacing around punctuation
    text = Regex.replace(~r/\s+([.,;:!?])/, text, "\\1")

    # Keep important headings (= and - underlined headings)
    text = Regex.replace(~r/(?m)^([^\n]+)\n[=]+\s*$/, text, "\\1\n")
    text = Regex.replace(~r/(?m)^([^\n]+)\n[-]+\s*$/, text, "\\1\n")

    # Trim leading/trailing whitespace
    String.trim(text)
  end
end
