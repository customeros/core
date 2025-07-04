import { useEffect } from 'react';
import { useLexicalComposerContext } from '@lexical/react/LexicalComposerContext';

import { $getRoot, TextNode, ParagraphNode } from 'lexical';
import { validateEmail } from 'src/components/Editor/utils/validateEmail';

const validLinkedInProfileUrl = (url: string): boolean => {
  const re = /linkedin\.com\/in\/[^/]+\/?$/;

  return re.test(url);
};

export function InputValidationPlugin({ type }: { type: 'linkedin' | 'email' }) {
  const [editor] = useLexicalComposerContext();

  useEffect(() => {
    return editor.registerTextContentListener(() => {
      editor.update(() => {
        const root = $getRoot();

        root.getChildren().forEach(paragraphNode => {
          if (paragraphNode instanceof ParagraphNode) {
            // Iterate through each child of the paragraph
            paragraphNode.getChildren().forEach(textNode => {
              if (textNode instanceof TextNode) {
                const textContent = textNode.getTextContent();

                const isInvalid =
                  type === 'email'
                    ? validateEmail(textContent)
                    : !validLinkedInProfileUrl(textContent);

                const element = editor.getElementByKey(textNode.getKey());

                if (element) {
                  if (isInvalid && textContent.trim() !== '') {
                    element.classList.add('lexical-invalid-text');
                  } else {
                    element.classList.remove('lexical-invalid-text');
                  }
                }
              }
            });
          }
        });
      });
    });
  }, [editor, type]);

  return null;
}
