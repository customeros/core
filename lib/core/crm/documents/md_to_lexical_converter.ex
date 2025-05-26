defmodule Core.Crm.Documents.MdToLexicalConverter do
  @moduledoc """
  Converts Markdown documents to Lexical editor state format.
  Supports comprehensive Markdown syntax including links, images, tables, and more.
  """

  import Bitwise

  @doc """
  Converts a markdown string to Lexical state JSON.

  ## Examples

      iex> markdown = "# Hello World\\n\\nThis is a paragraph."
      iex> MarkdownToLexical.convert(markdown)
      "{\"root\":{\"children\":[...],\"type\":\"root\"}}"
  """
  def convert(markdown_string) do
    markdown_string
    |> Earmark.as_ast!()
    |> ast_to_lexical()
    |> Jason.encode!()
  end

  # Convert Earmark AST to Lexical format
  defp ast_to_lexical(ast_nodes) do
    children = Enum.map(ast_nodes, &convert_node/1)

    %{
      "root" => %{
        "children" => children,
        "type" => "root"
      }
    }
  end

  # Convert individual AST nodes to Lexical nodes
  defp convert_node({"h1", _attrs, content}) do
    %{
      "type" => "heading",
      "tag" => "h1",
      "children" => convert_inline_content(content)
    }
  end

  defp convert_node({"h2", _attrs, content}) do
    %{
      "type" => "heading",
      "tag" => "h2",
      "children" => convert_inline_content(content)
    }
  end

  defp convert_node({"h3", _attrs, content}) do
    %{
      "type" => "heading",
      "tag" => "h3",
      "children" => convert_inline_content(content)
    }
  end

  defp convert_node({"h4", _attrs, content}) do
    %{
      "type" => "heading",
      "tag" => "h4",
      "children" => convert_inline_content(content)
    }
  end

  defp convert_node({"h5", _attrs, content}) do
    %{
      "type" => "heading",
      "tag" => "h5",
      "children" => convert_inline_content(content)
    }
  end

  defp convert_node({"h6", _attrs, content}) do
    %{
      "type" => "heading",
      "tag" => "h6",
      "children" => convert_inline_content(content)
    }
  end

  defp convert_node({"p", _attrs, content}) do
    %{
      "type" => "paragraph",
      "children" => convert_inline_content(content)
    }
  end

  defp convert_node({"ul", _attrs, list_items}) do
    %{
      "type" => "list",
      "listType" => "bullet",
      "start" => 1,
      "children" => Enum.map(list_items, &convert_list_item/1)
    }
  end

  defp convert_node({"ol", attrs, list_items}) do
    start_value = get_attr(attrs, "start", "1") |> String.to_integer()

    %{
      "type" => "list",
      "listType" => "number",
      "start" => start_value,
      "children" => Enum.map(list_items, &convert_list_item/1)
    }
  end

  defp convert_node({"blockquote", _attrs, content}) do
    %{
      "type" => "quote",
      "children" => Enum.map(content, &convert_node/1)
    }
  end

  defp convert_node({"pre", _attrs, [{"code", code_attrs, [code_content]}]}) do
    language = get_language_from_attrs(code_attrs)

    %{
      "type" => "code",
      "language" => language,
      "children" => [
        %{
          "type" => "text",
          "text" => code_content,
          "format" => 0
        }
      ]
    }
  end

  # Handle standalone code blocks without pre wrapper
  defp convert_node({"code", attrs, [content]}) when is_binary(content) do
    language = get_language_from_attrs(attrs)

    %{
      "type" => "code",
      "language" => language,
      "children" => [
        %{
          "type" => "text",
          "text" => content,
          "format" => 0
        }
      ]
    }
  end

  # Handle tables
  defp convert_node({"table", _attrs, content}) do
    {header_row, body_rows} = extract_table_content(content)

    %{
      "type" => "table",
      "children" => [
        %{
          "type" => "tablerow",
          "children" =>
            Enum.map(header_row, fn cell ->
              %{
                "type" => "tablecell",
                "headerCell" => true,
                "children" => convert_inline_content(cell)
              }
            end)
        }
        | Enum.map(body_rows, fn row ->
            %{
              "type" => "tablerow",
              "children" =>
                Enum.map(row, fn cell ->
                  %{
                    "type" => "tablecell",
                    "headerCell" => false,
                    "children" => convert_inline_content(cell)
                  }
                end)
            }
          end)
      ]
    }
  end

  # Handle horizontal rules
  defp convert_node({"hr", _attrs, _content}) do
    %{
      "type" => "horizontalrule"
    }
  end

  # Handle line breaks
  defp convert_node({"br", _attrs, _content}) do
    %{
      "type" => "linebreak"
    }
  end

  # Handle task lists (checkbox lists)
  defp convert_node({"input", attrs, _content}) do
    checked = get_attr(attrs, "checked", nil) != nil
    disabled = get_attr(attrs, "disabled", nil) != nil

    %{
      "type" => "check",
      "checked" => checked,
      "disabled" => disabled
    }
  end

  # Handle details/summary (collapsible content)
  defp convert_node({"details", _attrs, content}) do
    {summary, details_content} = extract_details_content(content)

    %{
      "type" => "collapsible-container",
      "open" => false,
      "children" => [
        %{
          "type" => "collapsible-title",
          "children" => convert_inline_content(summary)
        },
        %{
          "type" => "collapsible-content",
          "children" => Enum.map(details_content, &convert_node/1)
        }
      ]
    }
  end

  # Fallback for unknown block elements
  defp convert_node({_tag, _attrs, content}) when is_list(content) do
    %{
      "type" => "paragraph",
      "children" => convert_inline_content(content)
    }
  end

  defp convert_node(text) when is_binary(text) do
    %{
      "type" => "text",
      "text" => text,
      "format" => 0
    }
  end

  # Convert list items
  defp convert_list_item({"li", _attrs, content}) do
    # Check if this is a task list item
    case has_task_checkbox?(content) do
      {true, checked, remaining_content} ->
        %{
          "type" => "listitem",
          "checked" => checked,
          "children" => convert_inline_content(remaining_content)
        }

      false ->
        %{
          "type" => "listitem",
          "children" => convert_inline_content(content)
        }
    end
  end

  # Convert inline content (text with formatting)
  defp convert_inline_content(content) when is_list(content) do
    Enum.flat_map(content, &convert_inline_node/1)
  end

  defp convert_inline_content(content) when is_binary(content) do
    [
      %{
        "type" => "text",
        "text" => content,
        "format" => 0
      }
    ]
  end

  # Convert inline formatting nodes
  defp convert_inline_node({"strong", _attrs, content}) do
    text_content = extract_text_content(content)

    [
      %{
        "type" => "text",
        "text" => text_content,
        # Bold format
        "format" => 1
      }
    ]
  end

  defp convert_inline_node({"em", _attrs, content}) do
    text_content = extract_text_content(content)

    [
      %{
        "type" => "text",
        "text" => text_content,
        # Italic format
        "format" => 2
      }
    ]
  end

  defp convert_inline_node({"del", _attrs, content}) do
    text_content = extract_text_content(content)

    [
      %{
        "type" => "text",
        "text" => text_content,
        # Strikethrough format
        "format" => 8
      }
    ]
  end

  defp convert_inline_node({"s", _attrs, content}) do
    text_content = extract_text_content(content)

    [
      %{
        "type" => "text",
        "text" => text_content,
        # Strikethrough format
        "format" => 8
      }
    ]
  end

  defp convert_inline_node({"u", _attrs, content}) do
    text_content = extract_text_content(content)

    [
      %{
        "type" => "text",
        "text" => text_content,
        # Underline format
        "format" => 4
      }
    ]
  end

  defp convert_inline_node({"mark", _attrs, content}) do
    text_content = extract_text_content(content)

    [
      %{
        "type" => "text",
        "text" => text_content,
        # Highlight format
        "format" => 32
      }
    ]
  end

  defp convert_inline_node({"sub", _attrs, content}) do
    text_content = extract_text_content(content)

    [
      %{
        "type" => "text",
        "text" => text_content,
        # Subscript format
        "format" => 64
      }
    ]
  end

  defp convert_inline_node({"sup", _attrs, content}) do
    text_content = extract_text_content(content)

    [
      %{
        "type" => "text",
        "text" => text_content,
        # Superscript format
        "format" => 128
      }
    ]
  end

  defp convert_inline_node({"code", _attrs, content}) do
    text_content = extract_text_content(content)

    [
      %{
        "type" => "text",
        "text" => text_content,
        # Code format
        "format" => 16
      }
    ]
  end

  # Handle links
  defp convert_inline_node({"a", attrs, content}) do
    href = get_attr(attrs, "href", "")
    title = get_attr(attrs, "title", "")
    text_content = extract_text_content(content)

    link_node = %{
      "type" => "link",
      "url" => href,
      "children" => [
        %{
          "type" => "text",
          "text" => text_content,
          "format" => 0
        }
      ]
    }

    # Add title if present
    link_node =
      if title != "", do: Map.put(link_node, "title", title), else: link_node

    [link_node]
  end

  # Handle images
  defp convert_inline_node({"img", attrs, _content}) do
    src = get_attr(attrs, "src", "")
    alt = get_attr(attrs, "alt", "")
    title = get_attr(attrs, "title", "")
    width = get_attr(attrs, "width", "")
    height = get_attr(attrs, "height", "")

    image_node = %{
      "type" => "image",
      "src" => src,
      "altText" => alt
    }

    # Add optional attributes if present
    image_node =
      if title != "", do: Map.put(image_node, "title", title), else: image_node

    image_node =
      if width != "",
        do: Map.put(image_node, "width", parse_dimension(width)),
        else: image_node

    image_node =
      if height != "",
        do: Map.put(image_node, "height", parse_dimension(height)),
        else: image_node

    [image_node]
  end

  # Handle keyboard shortcuts
  defp convert_inline_node({"kbd", _attrs, content}) do
    text_content = extract_text_content(content)

    [
      %{
        "type" => "text",
        "text" => text_content,
        # Keyboard format (custom)
        "format" => 256
      }
    ]
  end

  # Handle line breaks
  defp convert_inline_node({"br", _attrs, _content}) do
    [
      %{
        "type" => "linebreak"
      }
    ]
  end

  # Handle span elements (may have custom classes or styles)
  defp convert_inline_node({"span", attrs, content}) do
    # Check for special classes or styles that might indicate formatting
    class = get_attr(attrs, "class", "")
    style = get_attr(attrs, "style", "")

    format = determine_span_format(class, style)
    text_content = extract_text_content(content)

    [
      %{
        "type" => "text",
        "text" => text_content,
        "format" => format
      }
    ]
  end

  defp convert_inline_node(text) when is_binary(text) do
    [
      %{
        "type" => "text",
        "text" => text,
        "format" => 0
      }
    ]
  end

  defp convert_inline_node({_tag, _attrs, content}) do
    # Fallback for unknown inline elements
    convert_inline_content(content)
  end

  # Helper functions
  defp extract_text_content(content) when is_list(content) do
    content
    |> Enum.map(&extract_text_content/1)
    |> Enum.join("")
  end

  defp extract_text_content(text) when is_binary(text), do: text

  defp extract_text_content({_tag, _attrs, content}),
    do: extract_text_content(content)

  defp get_attr(attrs, key, default) do
    case List.keyfind(attrs, key, 0) do
      {^key, value} -> value
      nil -> default
    end
  end

  defp get_language_from_attrs(attrs) do
    case get_attr(attrs, "class", "") do
      "language-" <> lang ->
        lang

      "lang-" <> lang ->
        lang

      "" ->
        ""

      class_string ->
        # Try to extract language from class string
        case Regex.run(~r/(?:language-|lang-)(\w+)/, class_string) do
          [_, lang] -> lang
          nil -> ""
        end
    end
  end

  defp extract_table_content(content) do
    thead =
      Enum.find(content, fn
        {"thead", _, _} -> true
        _ -> false
      end)

    tbody =
      Enum.find(content, fn
        {"tbody", _, _} -> true
        _ -> false
      end)

    header_row =
      case thead do
        {"thead", _, [{"tr", _, header_cells}]} ->
          Enum.map(header_cells, fn
            {"th", _, cell_content} -> cell_content
            {"td", _, cell_content} -> cell_content
          end)

        nil ->
          []
      end

    body_rows =
      case tbody do
        {"tbody", _, rows} ->
          Enum.map(rows, fn
            {"tr", _, cells} ->
              Enum.map(cells, fn
                {"td", _, cell_content} -> cell_content
                {"th", _, cell_content} -> cell_content
              end)
          end)

        nil ->
          []
      end

    {header_row, body_rows}
  end

  defp extract_details_content(content) do
    summary =
      Enum.find_value(content, fn
        {"summary", _, summary_content} -> summary_content
        _ -> nil
      end) || ["Details"]

    details_content =
      Enum.reject(content, fn
        {"summary", _, _} -> true
        _ -> false
      end)

    {summary, details_content}
  end

  defp has_task_checkbox?(content) do
    case content do
      [{"input", attrs, _} | remaining] ->
        type = get_attr(attrs, "type", "")

        if type == "checkbox" do
          checked = get_attr(attrs, "checked", nil) != nil
          {true, checked, remaining}
        else
          false
        end

      _ ->
        false
    end
  end

  defp parse_dimension(dim_string) do
    case Integer.parse(dim_string) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp determine_span_format(class, style) do
    format = 0

    # Check class-based formatting
    format =
      if String.contains?(class, "bold") or String.contains?(class, "strong"),
        do: format ||| 1,
        else: format

    format =
      if String.contains?(class, "italic") or String.contains?(class, "em"),
        do: format ||| 2,
        else: format

    format =
      if String.contains?(class, "underline"), do: format ||| 4, else: format

    format =
      if String.contains?(class, "strike"), do: format ||| 8, else: format

    format = if String.contains?(class, "code"), do: format ||| 16, else: format

    format =
      if String.contains?(class, "highlight"), do: format ||| 32, else: format

    # Check style-based formatting
    format =
      if String.contains?(style, "font-weight:bold") or
           String.contains?(style, "font-weight: bold"),
         do: format ||| 1,
         else: format

    format =
      if String.contains?(style, "font-style:italic") or
           String.contains?(style, "font-style: italic"),
         do: format ||| 2,
         else: format

    format =
      if String.contains?(style, "text-decoration:underline") or
           String.contains?(style, "text-decoration: underline"),
         do: format ||| 4,
         else: format

    format =
      if String.contains?(style, "text-decoration:line-through") or
           String.contains?(style, "text-decoration: line-through"),
         do: format ||| 8,
         else: format

    format
  end
end
