import { useState, useEffect, useMemo } from 'react';

import { router } from '@inertiajs/react';
import { Icon } from 'src/components/Icon';
import { Editor } from 'src/components/Editor/Editor';
import { IconButton } from 'src/components/IconButton';
import {
  ScrollAreaRoot,
  ScrollAreaThumb,
  ScrollAreaViewport,
  ScrollAreaScrollbar,
} from 'src/components/ScrollArea';
import { usePresence } from 'src/providers/PresenceProvider';
import { usePage } from '@inertiajs/react';
import { Tenant } from 'src/types';

export const DocumentEditor = () => {
  const page = usePage();
  const tenantId = (page.props.tenant as Tenant).id;
  const [viewMode, setViewMode] = useState('default');
  const docId = new URLSearchParams(window.location.search).get('doc');
  const urlViewMode = new URLSearchParams(window.location.search).get('viewMode');

  const { presentUsers, currentUserId } = usePresence();

  const presenceUser = useMemo(() => {
    const found = presentUsers.find(u => u.user_id === currentUserId);

    if (!found?.username || !found?.color) return undefined;

    return {
      username: found.username,
      cursorColor: found.color,
    };
  }, [currentUserId, presentUsers]);

  useEffect(() => {
    if (urlViewMode) {
      setViewMode(urlViewMode);
    }
  }, [urlViewMode]);

  const handleViewModeChange = () => {
    const params = new URLSearchParams(window.location.search);
    if (viewMode === 'default') {
      params.set('viewMode', 'focus');
      setViewMode('focus');
    } else {
      params.delete('viewMode');
      setViewMode('default');
    }
    router.visit(window.location.pathname + '?' + params.toString(), { preserveState: true });
  };

  const closeEditor = () => {
    router.visit('/leads', {
      preserveState: true,
      replace: true,
      preserveScroll: true,
    });
  };

  return (
    <>
      <ScrollAreaRoot>
        <ScrollAreaViewport>
          <div className="relative w-full h-full bg-white px-6">
            <div className="relative bg-white h-full mx-auto pt-[2px] w-full md:min-w-[680px] max-w-[680px]">
              <div className="flex items-center w-full justify-end mb-3 gap-2">
                <IconButton
                  size="xs"
                  variant="ghost"
                  aria-label="toggle view mode"
                  className="hidden md:flex"
                  onClick={handleViewModeChange}
                  icon={<Icon name={viewMode === 'default' ? 'expand-01' : 'collapse-01'} />}
                />
                <IconButton
                  size="xs"
                  variant="ghost"
                  onClick={closeEditor}
                  aria-label="close document"
                  icon={<Icon name="x-close" />}
                />
              </div>

              {docId ? (
                <Editor
                  documentId={docId}
                  useYjs={true}
                  namespace="leads"
                  user={presenceUser}
                  key={docId}
                />
              ) : (
                <div className="flex items-center justify-center h-full">
                  Preparing account brief...
                </div>
              )}

              <div className="h-20 w-full"></div>
            </div>
          </div>
        </ScrollAreaViewport>
        <ScrollAreaScrollbar orientation="vertical">
          <ScrollAreaThumb />
        </ScrollAreaScrollbar>
      </ScrollAreaRoot>
    </>
  );
};

// const colorMap: Record<string, string[]> = {
//   gray: ['hover:ring-gray-400', 'bg-gray-50', 'text-gray-500'],
//   error: ['hover:ring-error-400', 'bg-error-50', 'text-error-500'],
//   warning: ['hover:ring-warning-400', 'bg-warning-50', 'text-warning-500'],
//   success: ['hover:ring-success-400', 'bg-success-50', 'text-success-500'],
//   grayWarm: ['hover:ring-grayWarm-400', 'bg-grayWarm-50', 'text-grayWarm-500'],
//   moss: ['hover:ring-moss-400', 'bg-moss-50', 'text-moss-500'],
//   blueLight: ['hover:ring-blueLight-400', 'bg-blueLight-50', 'text-blueLight-500'],
//   indigo: ['hover:ring-indigo-400', 'bg-indigo-50', 'text-indigo-500'],
//   violet: ['hover:ring-violet-400', 'bg-violet-50', 'text-violet-500'],
//   pink: ['hover:ring-pink-400', 'bg-pink-50', 'text-pink-500'],
// };
