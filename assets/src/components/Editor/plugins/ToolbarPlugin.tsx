import * as React from 'react';
import { useState, useEffect } from 'react';
import { useLexicalComposerContext } from '@lexical/react/LexicalComposerContext';

import clsx from 'clsx';
import { Icon } from 'src/components/Icon/Icon';
import { $setBlocksType } from '@lexical/selection';
import { IconButton } from 'src/components/IconButton';
import { $isQuoteNode, $createQuoteNode } from '@lexical/rich-text';
import { $isListNode, $createListNode, $isListItemNode } from '@lexical/list';
import {
  LexicalNode,
  UNDO_COMMAND,
  REDO_COMMAND,
  $getSelection,
  TextFormatType,
  CAN_UNDO_COMMAND,
  CAN_REDO_COMMAND,
  $isRangeSelection,
  FORMAT_TEXT_COMMAND,
  $createParagraphNode,
  SELECTION_CHANGE_COMMAND,
} from 'lexical';

const activeStyle = 'bg-gray-100 text-gray-700 hover:bg-gray-100';

const LowPriority = 1;

export default function ToolbarPlugin(): React.ReactNode {
  const [editor] = useLexicalComposerContext();
  const [isStrikethrough, setIsStrikethrough] = useState(false);
  const [isBlockquote, setIsBlockquote] = useState(false);
  const [isBold, setIsBold] = useState(false);
  const [canUndo, setCanUndo] = useState(false);
  const [canRedo, setCanRedo] = useState(false);
  const [isItalic, setIsItalic] = useState(false);
  const [isOrderedList, setIsOrderedList] = useState(false);
  const [isUnorderedList, setIsUnorderedList] = useState(false);

  const updateToolbar = React.useCallback(() => {
    const selection = $getSelection();

    if (!$isRangeSelection(selection)) {
      return;
    }

    setIsBold(selection.hasFormat('bold'));
    setIsItalic(selection.hasFormat('italic'));
    setIsStrikethrough(selection.hasFormat('strikethrough'));

    const nodes = selection.getNodes();
    const existingQuote = nodes.some(node => $isQuoteNode(node) || $isQuoteNode(node.getParent()));

    setIsBlockquote(existingQuote);

    let isUnordered = false;
    let isOrdered = false;
    // const isCheck = false;

    selection.getNodes().forEach(node => {
      let currentNode: LexicalNode | null = node;

      while (currentNode != null) {
        if ($isListItemNode(currentNode)) {
          const parent = currentNode.getParent();

          if ($isListNode(parent)) {
            if (parent.getListType() === 'bullet') {
              isUnordered = true;
            } else if (parent.getListType() === 'number') {
              isOrdered = true;
            }
            // else if (parent.getListType() === 'check') {
            //   isCheck = true;
            // }
          }
        }

        // Move to parent node to continue checking
        currentNode = currentNode.getParent() as LexicalNode | null;
      }
    });

    setIsUnorderedList(isUnordered);
    setIsOrderedList(isOrdered);
  }, []);

  useEffect(() => {
    editor.registerUpdateListener(({ editorState }) => {
      editorState.read(() => {
        updateToolbar();
      });
    });

    editor.registerCommand(
      SELECTION_CHANGE_COMMAND,
      () => {
        updateToolbar();

        return false;
      },
      LowPriority
    );
    editor.registerCommand(
      CAN_UNDO_COMMAND,
      payload => {
        setCanUndo(payload);

        return false;
      },
      LowPriority
    );
    editor.registerCommand(
      CAN_REDO_COMMAND,
      payload => {
        setCanRedo(payload);

        return false;
      },
      LowPriority
    );
  }, [editor, updateToolbar]);

  const formatText = (format: TextFormatType) => {
    editor.dispatchCommand(FORMAT_TEXT_COMMAND, format);
  };

  const formatList = (type: 'number' | 'bullet') => {
    editor.update(() => {
      const selection = $getSelection();

      if (!$isRangeSelection(selection)) {
        return;
      }

      if ((type === 'number' && !isOrderedList) || (type === 'bullet' && !isUnorderedList)) {
        $setBlocksType(selection, () => $createListNode(type));
      } else {
        $setBlocksType(selection, () => $createParagraphNode());
      }
    });
  };

  const formatQuote = () => {
    editor.update(() => {
      const selection = $getSelection();

      if (!$isRangeSelection(selection)) {
        return;
      }

      if (!isBlockquote) {
        $setBlocksType(selection, () => $createQuoteNode());
      } else {
        $setBlocksType(selection, () => $createParagraphNode());
      }
    });
  };

  return (
    <div className="flex items-center">
      <IconButton
        size="xs"
        variant="ghost"
        aria-label="Undo"
        icon={<Icon name="arrow-block-down" className="text-inherit" />}
        className={clsx('rounded-sm', {
          [activeStyle]: canUndo,
        })}
        onMouseDown={e => {
          e.preventDefault();
          editor.dispatchCommand(UNDO_COMMAND, undefined);
        }}
      />

      <IconButton
        size="xs"
        variant="ghost"
        aria-label="Redo"
        icon={<Icon name="arrow-block-up" className="text-inherit" />}
        className={clsx('rounded-sm', {
          [activeStyle]: canRedo,
        })}
        onMouseDown={e => {
          e.preventDefault();
          editor.dispatchCommand(REDO_COMMAND, undefined);
        }}
      />

      <IconButton
        size="xs"
        variant="ghost"
        aria-label="Format text to bold"
        icon={<Icon name="bold-01" className="text-inherit" />}
        className={clsx('rounded-sm', {
          [activeStyle]: isBold,
        })}
        onMouseDown={e => {
          e.preventDefault();
          formatText('bold');
        }}
      />

      <IconButton
        size="xs"
        variant="ghost"
        aria-label="Format text with italic"
        icon={<Icon name="italic-01" className="text-inherit" />}
        className={clsx('rounded-sm', {
          [activeStyle]: isItalic,
        })}
        onMouseDown={e => {
          e.preventDefault();
          formatText('italic');
        }}
      />

      <IconButton
        size="xs"
        variant="ghost"
        aria-label="Format text with a strikethrough"
        icon={<Icon name="strikethrough-01" className="text-inherit" />}
        className={clsx('rounded-sm', {
          [activeStyle]: isStrikethrough,
        })}
        onMouseDown={e => {
          e.preventDefault();
          formatText('strikethrough');
        }}
      />

      <div className="h-5 w-[1px] bg-gray-400 mx-1" />

      <IconButton
        size="xs"
        variant="ghost"
        icon={<Icon name="list-bulleted" />}
        aria-label="Format text as an bullet list"
        className={clsx('rounded-sm', {
          [activeStyle]: isUnorderedList,
        })}
        onMouseDown={e => {
          e.preventDefault();
          formatList('bullet');
        }}
      />

      <IconButton
        size="xs"
        variant="ghost"
        aria-label="Format text as an ordered list"
        icon={<Icon name="list-numbered" className="text-inherit" />}
        className={clsx('rounded-sm', {
          [activeStyle]: isOrderedList,
        })}
        onMouseDown={e => {
          e.preventDefault();
          formatList('number');
        }}
      />

      <div className="h-5 w-[1px] bg-gray-400 mx-0.5" />

      <IconButton
        size="xs"
        variant="ghost"
        aria-label="Format text with block quote"
        icon={<Icon name="block-quote" className="text-inherit" />}
        className={clsx('rounded-sm', {
          [activeStyle]: isBlockquote,
        })}
        onMouseDown={e => {
          e.preventDefault();
          formatQuote();
        }}
      />
    </div>
  );
}
