import { useEffect, ClipboardEvent } from 'react';

import { $createLinkNode } from '@lexical/link';
import { $generateNodesFromDOM } from '@lexical/html';
import { useLexicalComposerContext } from '@lexical/react/LexicalComposerContext';
import { $getSelection, PASTE_COMMAND, $createTextNode, $isRangeSelection } from 'lexical';

export function LinkPastePlugin() {
  const [editor] = useLexicalComposerContext();

  useEffect(() => {
    const handlePaste = (event: ClipboardEvent) => {
      const selection = $getSelection();

      if ($isRangeSelection(selection)) {
        const clipboardData = event.clipboardData;
        const pastedData = clipboardData?.getData('text/plain');
        const selectedText = selection.getTextContent().trim();

        if (!pastedData) return;

        if (selectedText.length && isValidUrl(pastedData)) {
          editor.update(() => {
            const linkNode = $createLinkNode(pastedData);
            const textNode = $createTextNode(selectedText || pastedData);

            linkNode.append(textNode);
            selection.insertNodes([linkNode]);
          });
        } else {
          editor.update(() => {
            const htmlData = clipboardData?.getData('text/html');

            if (htmlData) {
              const parser = new DOMParser();
              const doc = parser.parseFromString(htmlData, 'text/html');

              // strip all formatting enforced by pre tags
              doc.querySelectorAll('pre')?.forEach(preEl => {
                if (!preEl.querySelector('code')) {
                  const span = doc.createElement('div');

                  // Move all child nodes into the new div
                  while (preEl.firstChild) {
                    span.appendChild(preEl.firstChild);
                  }
                  preEl.replaceWith(span);
                }
              });

              const nodes = $generateNodesFromDOM(editor, doc);

              selection.insertNodes(nodes);
            } else {
              const htmlData = convertPlainTextToHtml(pastedData);
              const parser = new DOMParser();
              const doc = parser.parseFromString(htmlData, 'text/html');
              const nodes = $generateNodesFromDOM(editor, doc);

              selection.insertNodes(nodes);
            }
          });
        }
      }
    };

    editor.registerCommand(
      PASTE_COMMAND,
      (event: ClipboardEvent) => {
        handlePaste(event);

        return true;
      },
      1
    );
  }, [editor]);

  return null;
}

export function convertPlainTextToHtml(plainText: string): string {
  // Escape HTML special characters to avoid XSS vulnerabilities
  const escapedText = plainText
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');

  // ensure variables are properly converted to nodes
  const textWithVariables = escapedText.replace(
    /\{\{([^}]+)\}\}/g,
    '<span data-lexical-variable>{{$1}}</span>'
  );

  // Replace newline characters with <br> tags
  return textWithVariables.replace(/\n/g, '<br>');
}

export function isValidUrl(string: string) {
  const urlWithProtocol = getExternalUrl(string);

  try {
    new URL(urlWithProtocol);

    return true;
  } catch (err) {
    return false;
  }
}
export const removeProtocolFromLink = (link: string): string => {
  const protocolIndex = link.indexOf('://');

  if (protocolIndex !== -1) {
    return link.slice(protocolIndex + 3);
  }

  return link;
};

export const getExternalUrl = (link: string) => {
  const linkWithoutProtocol = removeProtocolFromLink(link);

  return `https://${linkWithoutProtocol}`;
};

export const getFormattedLink = (url: string): string => {
  return url.replace(/^(https?:\/\/)?(www\.)?/i, '');
};
