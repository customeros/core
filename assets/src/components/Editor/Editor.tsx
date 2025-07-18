import type { EditorThemeClasses } from 'lexical';

import { ListPlugin } from '@lexical/react/LexicalListPlugin';
import { HistoryPlugin } from '@lexical/react/LexicalHistoryPlugin';
import { RichTextPlugin } from '@lexical/react/LexicalRichTextPlugin';
import { PlainTextPlugin } from '@lexical/react/LexicalPlainTextPlugin';
import { CheckListPlugin } from '@lexical/react/LexicalCheckListPlugin';
import { EditorRefPlugin } from '@lexical/react/LexicalEditorRefPlugin';
import { AutoFocusPlugin } from '@lexical/react/LexicalAutoFocusPlugin';
import { ContentEditable } from '@lexical/react/LexicalContentEditable';
import { LexicalErrorBoundary } from '@lexical/react/LexicalErrorBoundary';
import { CollaborationPlugin } from '@lexical/react/LexicalCollaborationPlugin';
import { TabIndentationPlugin } from '@lexical/react/LexicalTabIndentationPlugin';
import { LexicalComposer, InitialConfigType } from '@lexical/react/LexicalComposer';
import { MarkdownShortcutPlugin } from '@lexical/react/LexicalMarkdownShortcutPlugin';
import React, {
  useRef,
  useState,
  useEffect,
  forwardRef,
  useContext,
  useCallback,
  useImperativeHandle,
} from 'react';

import clsx from 'clsx';
import * as Y from 'yjs';
import { UndoManager } from 'yjs';
import { twMerge } from 'tailwind-merge';
import { TRANSFORMERS } from '@lexical/markdown';
import { cva, VariantProps } from 'class-variance-authority';
import { $insertNodes, $nodesOfType, LexicalEditor } from 'lexical';
import { $generateNodesFromDOM, $generateHtmlFromNodes } from '@lexical/html';

import { nodes } from './nodes/nodes';
import { HashtagNode } from './nodes/HashtagNode';
import MentionsPlugin from './plugins/MentionsPlugin';
import AutoLinkPlugin from './plugins/AutoLinkPlugin';
import HashtagsPlugin from './plugins/HashtagsPlugin';
import VariablePlugin from './plugins/VariablesPlugin';
import ToolbarPlugin from './plugins/ToolbarPlugin.tsx';
import { YjsUndoPlugin } from './plugins/YjsUndoPlugin';
import { LinkPastePlugin } from './plugins/PastePlugin.tsx';
import TextNodeTransformer from './nodes/TextTransformar.ts';
import { PhoenixChannelProvider } from './utils/y-phoenix-channel';
import { PhoenixSocketContext } from '../../providers/SocketProvider.tsx';
import FloatingLinkEditorPlugin from './plugins/FloatingLinkEditorPlugin';
import { FloatingMenuPlugin } from './plugins/FloatingTextFormatToolbarPlugin';

const theme: EditorThemeClasses = {
  paragraph: 'mb-2',
  heading: {
    h1: 'text-lg font-bold mb-4',
    h2: 'text-md font-bold mb-3',
    h3: 'text-sm font-bold mb-2',
    h4: 'text-sm font-medium mb-2',
    h5: 'text-sm font-medium mb-2',
  },
  list: {
    ulDepth: [
      'p-0 m-0 list-outside list-disc',
      'p-0 m-0 list-outside list-[circle]',
      'p-0 m-0 list-outside list-square',
      'p-0 m-0 list-outside list-disc',
      'p-0 m-0 list-outside list-[circle]',
      'p-0 m-0 list-outside list-square',
    ],
    nested: {
      listitem: 'editor__nestedListItem list-none',
    },
    ol: 'p-0 m-0 list-outside list-decimal mb-2',
    ul: 'p-0 m-0 list-outside mb-2',
    listitem: 'ml-8',
    olDepth: [
      'p-0 m-0 list-outside',
      'p-0 m-0 list-outside list-[upper-alpha]',
      'p-0 m-0 list-outside list-[lower-alpha]',
      'p-0 m-0 list-outside list-[upper-roman]',
      'p-0 m-0 list-outside list-[lower-roman]',
    ],
    listitemChecked: 'editor__listItemChecked',
    listitemUnchecked: 'editor__listItemUnchecked',
  },
  link: 'text-primary-700 hover:text-primary-600',
  text: {
    bold: 'editor-textBold',
    code: 'editor-textCode',
    italic: 'editor-textItalic',
    strikethrough: 'editor-textStrikethrough',
    subscript: 'editor-textSubscript',
    superscript: 'editor-textSuperscript',
    underline: 'editor-textUnderline',
    underlineStrikethrough: 'editor-textUnderlineStrikethrough',
  },
  quote: 'border-l-[2px] border-gray-300 pl-3 my-3',
};

const onError = (error: Error) => {
  console.error(error);
};

const contentEditableVariants = cva('focus:outline-none', {
  variants: {
    size: {
      xs: ['text-sm'],
      sm: ['text-sm'],
      md: ['text-base'],
      lg: ['text-lg'],
    },
  },
  defaultVariants: {
    size: 'md',
  },
});

type SelectOption = {
  label: string;
  value: string;
};

interface EditorProps extends VariantProps<typeof contentEditableVariants> {
  useYjs?: boolean;
  user_id?: string;
  namespace: string;
  dataTest?: string;
  className?: string;
  documentId?: string;
  placeholder?: string;
  isReadOnly?: boolean;
  usePlainText?: boolean;
  defaultHtmlValue?: string;
  mentionsOptions?: string[];
  variableOptions?: string[];
  children?: React.ReactNode;
  showToolbarBottom?: boolean;
  placeholderClassName?: string;
  hashtagsOptions?: SelectOption[];
  onChange?: (html: string) => void;
  onHashtagCreate?: (hashtag: string) => void;
  onHashtagSearch?: (q: string | null) => void;
  onMentionsSearch?: (q: string | null) => void;
  onHashtagsChange?: (hashtags: SelectOption[]) => void;
  onBlur?: (e: React.FocusEvent<HTMLDivElement>) => void;
  onFocus?: (e: React.FocusEvent<HTMLDivElement>) => void;
  user?: {
    username: string;
    cursorColor: string;
  };
  onKeyDown?: (e: React.KeyboardEvent<HTMLDivElement>) => void;
  onUndoStateChange?: (canUndo: boolean, canRedo: boolean) => void;
  undoRef?: React.RefObject<{
    undo: () => void;
    redo: () => void;
  } | null>;
}

export const Editor = forwardRef<LexicalEditor | null, EditorProps>(
  (
    {
      size,
      onBlur,
      dataTest,
      onFocus,
      children,
      onChange,
      className,
      namespace,
      onHashtagSearch,
      onHashtagCreate,
      onHashtagsChange,
      onMentionsSearch,
      defaultHtmlValue,
      hashtagsOptions = [],
      mentionsOptions = [],
      variableOptions = [],
      usePlainText = false,
      placeholderClassName,
      onKeyDown,
      useYjs = false,
      user,
      user_id,
      placeholder = 'Type something',
      showToolbarBottom = false,
      isReadOnly = false,
      onUndoStateChange,
      undoRef,
      documentId,
    },
    ref
  ) => {
    const editor = useRef<LexicalEditor | null>(null);
    const hasLoadedDefaultHtmlValue = useRef(false);
    const containerRef = useRef<HTMLDivElement>(null);
    const [floatingAnchorElem, setFloatingAnchorElem] = useState<HTMLDivElement>();
    const [_yjsProvider, setYjsProvider] = useState<PhoenixChannelProvider | null>(null);
    const [undoManager, setUndoManager] = useState<UndoManager | null>(null);
    const [_connectionStatus, setConnectionStatus] = useState<
      'disconnected' | 'connecting' | 'connected'
    >('disconnected');

    const { socket } = useContext(PhoenixSocketContext);

    const initialConfig: InitialConfigType = {
      namespace,
      theme,
      onError,
      nodes,
      editorState: useYjs ? null : undefined,
      editable: !isReadOnly,
    };

    const EditorPlugin = usePlainText ? PlainTextPlugin : RichTextPlugin;

    const onRef = (_floatingAnchorElem: HTMLDivElement) => {
      if (_floatingAnchorElem !== null) {
        setFloatingAnchorElem(_floatingAnchorElem);
      }
    };

    useImperativeHandle(ref, () => editor.current as LexicalEditor);

    useEffect(() => {
      if (useYjs) return;

      editor.current?.update(() => {
        if (!editor?.current || hasLoadedDefaultHtmlValue.current) return;

        if (defaultHtmlValue) {
          const parser = new DOMParser();
          const dom = parser.parseFromString(defaultHtmlValue, 'text/html');
          const nodes = $generateNodesFromDOM(editor?.current, dom);

          $insertNodes(nodes);
          hasLoadedDefaultHtmlValue.current = true;
        }
      });

      const dispose = editor?.current?.registerUpdateListener(({ editorState }) => {
        editorState.read(() => {
          if (!editor?.current) return;

          const hashtagNodes = $nodesOfType(HashtagNode);
          const html = $generateHtmlFromNodes(editor?.current);

          onChange?.(html);
          onHashtagsChange?.(hashtagNodes.map(node => node.__hashtag));
        });
      });

      return () => {
        dispose?.();
      };
    }, [useYjs]);

    const providerFactory = useCallback(
      (id: string, yjsDocMap: Map<string, Y.Doc>) => {
        if (!useYjs || !socket) {
          return null;
        }

        const doc = (() => {
          if (yjsDocMap.has(id)) {
            const doc = yjsDocMap.get(id)!;

            doc.load();

            return doc;
          }

          const doc = new Y.Doc();

          yjsDocMap.set(id, doc);

          return doc;
        })();

        const provider = new PhoenixChannelProvider(socket!, `documents:${id}`, doc, {
          disableBc: true,
          params: { user_id },
        });

        provider.on('status', e => {
          setConnectionStatus(e.status);
        });

        const yXmlFragment = doc.get('lexical', Y.XmlFragment);
        const newUndoManager = new UndoManager(yXmlFragment, {
          captureTimeout: 500,
          trackedOrigins: new Set([null, provider]),
        });

        setTimeout(() => setUndoManager(newUndoManager), 0);
        setTimeout(() => setYjsProvider(provider), 0);

        return provider;
      },
      [socket, useYjs]
    );

    useEffect(() => {
      if (undoRef && undoManager) {
        undoRef.current = {
          undo: () => undoManager.undo(),
          redo: () => undoManager.redo(),
        };
      }

      return () => {
        if (undoRef) {
          undoRef.current = null;
        }
      };
    }, [undoManager, undoRef]);

    if (!socket) {
      return <div>No socket</div>;
    }

    return (
      <div
        ref={containerRef}
        className="relative w-full h-fit lexical-editor cursor-text animate-fadeIn"
      >
        <LexicalComposer initialConfig={initialConfig}>
          <EditorRefPlugin editorRef={editor} />
          <CheckListPlugin />
          <AutoLinkPlugin />
          {!useYjs && <HistoryPlugin />}
          <AutoFocusPlugin />
          <TextNodeTransformer />
          <ListPlugin />

          <MarkdownShortcutPlugin transformers={TRANSFORMERS} />

          {onMentionsSearch && (
            <MentionsPlugin options={mentionsOptions} onSearch={onMentionsSearch} />
          )}
          <TabIndentationPlugin />

          <LinkPastePlugin />

          {variableOptions?.length > 0 && <VariablePlugin options={variableOptions} />}

          {onHashtagSearch && (
            <HashtagsPlugin
              options={hashtagsOptions}
              onCreate={onHashtagCreate}
              onSearch={onHashtagSearch}
            />
          )}

          {floatingAnchorElem && !usePlainText && (
            <>
              <FloatingLinkEditorPlugin anchorElem={floatingAnchorElem} />
              <FloatingMenuPlugin element={floatingAnchorElem} variableOptions={variableOptions} />
            </>
          )}
          <EditorPlugin
            ErrorBoundary={LexicalErrorBoundary}
            placeholder={
              <span
                onClick={() => editor.current?.focus()}
                className={twMerge(
                  contentEditableVariants({
                    size,
                    className: placeholderClassName,
                  }),
                  'absolute top-0 text-gray-400'
                )}
              >
                {placeholder}
              </span>
            }
            contentEditable={
              <div ref={onRef} className={clsx('relative', className)}>
                <ContentEditable
                  onBlur={onBlur}
                  onFocus={onFocus}
                  autoFocus={false}
                  spellCheck="false"
                  data-test={dataTest}
                  onKeyDown={e => (onKeyDown ? onKeyDown(e) : e.stopPropagation())}
                  className={twMerge(contentEditableVariants({ size, className }))}
                />
              </div>
            }
          />

          {documentId && (
            <CollaborationPlugin
              id={documentId}
              shouldBootstrap={false}
              username={user?.username}
              cursorColor={user?.cursorColor}
              cursorsContainerRef={containerRef}
              // eslint-disable-next-line @typescript-eslint/no-explicit-any
              providerFactory={providerFactory as any}
            />
          )}

          {useYjs && (
            <YjsUndoPlugin undoManager={undoManager} onUndoStateChange={onUndoStateChange} />
          )}
          <div
            className={clsx(
              'w-full flex justify-between items-center mt-2',
              !showToolbarBottom && 'justify-end'
            )}
          >
            {showToolbarBottom && <ToolbarPlugin />}
            {children}
          </div>
        </LexicalComposer>
      </div>
    );
  }
);

export default Editor;
