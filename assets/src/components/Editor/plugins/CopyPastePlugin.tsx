import { useEffect, ClipboardEvent } from 'react';

import { $createLinkNode } from '@lexical/link';
import { $generateNodesFromDOM } from '@lexical/html';
import { useLexicalComposerContext } from '@lexical/react/LexicalComposerContext';
import { $getSelection, PASTE_COMMAND, COPY_COMMAND, CUT_COMMAND, $createTextNode, $isRangeSelection } from 'lexical';

import { convertPlainTextToHtml } from 'src/components/Editor/utils/convertPlainTextToHtml';

/**
 * PastePlugin handles copy, cut, and paste operations in the Lexical editor.
 * 
 * Features:
 * - Copy/Cut: Preserves plain text content
 * - Paste:
 *   1. URL + Selected Text: Creates a clickable link
 *   2. HTML Content: Preserves formatting
 *   3. Plain Text: Converts to formatted HTML
 * 
 * Note: Currently, copy/cut operations only preserve plain text.
 * HTML formatting preservation during copy/cut is planned for future implementation.
 */
export function CopyPastePlugin() {
  const [editor] = useLexicalComposerContext();

  // Validates if a string is a valid absolute URL
  const isValidUrl = (url: string): boolean => {
    try {
      // Only accept absolute URLs
      const parsedUrl = new URL(url);
      return parsedUrl.protocol.startsWith('http');
    } catch {
      return false;
    }
  };

  // Convert selected text into a clickable link
  const createLinkFromSelection = (url: string, selectedText: string) => {
    editor.update(() => {
      const linkNode = $createLinkNode(url);
      const textNode = $createTextNode(selectedText || url);
      linkNode.append(textNode);
      $getSelection()?.insertNodes([linkNode]);
    });
  };

  // Handle pasting of HTML content while preserving formatting
  const handleHtmlPaste = (htmlContent: string) => {
    editor.update(() => {
      const parser = new DOMParser();
      const doc = parser.parseFromString(htmlContent, 'text/html');

      // Clean up pre tags that don't contain code blocks
      doc.querySelectorAll('pre')?.forEach(preEl => {
        if (!preEl.querySelector('code')) {
          const div = doc.createElement('div');
          while (preEl.firstChild) {
            div.appendChild(preEl.firstChild);
          }
          preEl.replaceWith(div);
        }
      });

      const nodes = $generateNodesFromDOM(editor, doc);
      $getSelection()?.insertNodes(nodes);
    });
  };

  // Convert plain text to formatted HTML
  const handlePlainTextPaste = (text: string) => {
    editor.update(() => {
      const htmlContent = convertPlainTextToHtml(text);
      const parser = new DOMParser();
      const doc = parser.parseFromString(htmlContent, 'text/html');
      const nodes = $generateNodesFromDOM(editor, doc);
      $getSelection()?.insertNodes(nodes);
    });
  };

  useEffect(() => {
    // Handle paste operations
    const handlePaste = (event: ClipboardEvent) => {
      const selection = $getSelection();
      if (!$isRangeSelection(selection)) return;

      const clipboardData = event.clipboardData;
      const pastedText = clipboardData?.getData('text/plain');
      const pastedHtml = clipboardData?.getData('text/html');
      const selectedText = selection.getTextContent().trim();

      if (!pastedText) return;

      // Case 1: Selected text + URL = Create link
      if (selectedText.length && isValidUrl(pastedText)) {
        createLinkFromSelection(pastedText, selectedText);
        return;
      }

      // Case 2: HTML content = Preserve formatting
      if (pastedHtml) {
        handleHtmlPaste(pastedHtml);
        return;
      }

      // Case 3: Plain text = Convert to formatted HTML
      handlePlainTextPaste(pastedText);
    };

    // Handle copy operations
    const handleCopy = (event: ClipboardEvent) => {
      const selection = $getSelection();
      if (!$isRangeSelection(selection)) return;

      const selectedText = selection.getTextContent();
      
      // For now, we'll just copy the plain text
      // TODO: Implement proper HTML serialization when needed
      if (event.clipboardData) {
        event.clipboardData.setData('text/plain', selectedText);
      }
    };

    // Register command handlers
    editor.registerCommand(
      PASTE_COMMAND,
      (event: ClipboardEvent) => {
        handlePaste(event);
        return true;
      },
      1
    );

    editor.registerCommand(
      COPY_COMMAND,
      (event: ClipboardEvent) => {
        handleCopy(event);
        return true;
      },
      1
    );

    editor.registerCommand(
      CUT_COMMAND,
      (event: ClipboardEvent) => {
        handleCopy(event);
        // The default cut behavior will handle removing the selected content
        return false;
      },
      1
    );
  }, [editor]);

  return null;
}
