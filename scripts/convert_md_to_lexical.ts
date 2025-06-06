import { marked } from "marked";
import { createHeadlessEditor } from "@lexical/headless";
import { nodes } from "./nodes";
import { Window } from "happy-dom";
import { $generateNodesFromDOM } from "@lexical/html";
import { $getRoot, $insertNodes } from "lexical";

// console.log = () => {};
// console.info = () => {};
// console.error = () => {};
// console.warn = () => {};

/**
 * Converts a Markdown string to Lexical editor state JSON.
 *
 * @param markdown The Markdown string to convert
 * @returns The Lexical editor state as a JSON string
 */
export async function convertMarkdownToLexical(
  markdown: string
): Promise<string> {
  // Create a headless editor with minimal configuration
  const editor = createHeadlessEditor({
    nodes,
    onError: (error) => {
      console.error("Error in headless editor:", error);
    },
  });

  // Parse markdown to HTML
  const html = await marked.parse(markdown);

  // Convert HTML to Lexical state
  let lexicalState = "";
  editor.update(
    () => {
      // Create a window with happy-dom
      const window = new Window();
      const document = window.document;

      // Set the HTML content
      document.body.innerHTML = html;

      const nodes = $generateNodesFromDOM(
        editor,
        document as unknown as Document
      );

      $getRoot().select();
      $insertNodes(nodes);
      $getRoot().select();
    },
    {
      discrete: true,
      onUpdate: () => {
        lexicalState = JSON.stringify(editor.getEditorState());
      },
    }
  );

  return lexicalState;
}

/**
 * Main CLI function that processes command line arguments and outputs the result
 */
async function main() {
  try {
    // Get command line arguments
    const args = process.argv.slice(2);

    // Check if we have the required arguments
    if (args.length < 1) {
      process.stderr.write(
        "Usage: bun run convert_md_to_lexical.ts <markdown_file>\n"
      );
      process.exit(1);
    }

    const markdownFile = args[0];

    try {
      // Read the markdown file
      const markdown = await Bun.file(markdownFile).text();

      // Convert markdown to lexical state
      const lexicalState = await convertMarkdownToLexical(markdown);

      // Output the lexical state to stdout
      process.stdout.write(lexicalState);
    } catch (err) {
      process.stderr.write(`Error processing file: ${err}\n`);
      process.exit(1);
    }
  } catch (error) {
    // Handle any errors
    process.stderr.write(
      `Error: ${error instanceof Error ? error.message : String(error)}\n`
    );
    process.exit(1);
  }
}

main();
