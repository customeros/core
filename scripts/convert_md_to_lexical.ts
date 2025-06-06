import { marked } from "marked";
import { createHeadlessEditor } from "@lexical/headless";
import { nodes } from "./nodes";
import { JSDOM } from "jsdom";
import { $generateNodesFromDOM } from "@lexical/html";
import { $getRoot, $insertNodes } from "lexical";

console.log = () => {};
console.info = () => {};
console.error = () => {};
console.warn = () => {};

// Mock the XHR worker module that JSDOM is looking for
const xhrWorkerMock = {
  XHRWorker: class {
    postMessage() {}
    terminate() {}
  },
  createWorker: () => new xhrWorkerMock.XHRWorker(),
};

// Mock the module resolution
(global as any).require = (path: string) => {
  if (path.includes("xhr-sync-worker.js")) {
    return xhrWorkerMock;
  }
  throw new Error(`Cannot find module '${path}'`);
};

// Create a JSDOM instance
const dom = new JSDOM("<!DOCTYPE html><html><body></body></html>");
global.document = dom.window.document;
(global as any).window = dom.window;

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
      const parser = new dom.window.DOMParser();
      const doc = parser.parseFromString(html, "text/html");

      const nodes = $generateNodesFromDOM(editor, doc);

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
