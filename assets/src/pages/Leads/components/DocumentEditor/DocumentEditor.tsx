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
import { toastSuccess } from 'src/components/Toast/success';
import { usePresence } from 'src/providers/PresenceProvider';
import { usePage } from '@inertiajs/react';
import { Lead, Tenant, User } from 'src/types';
import { PageProps } from '@inertiajs/core';
import { FeaturedIcon } from 'src/components/FeaturedIcon/FeaturedIcon';

export const DocumentEditor = () => {
  const page = usePage<PageProps & { tenant: Tenant; currentUser: User; companies: Lead[] }>();
  const [viewMode, setViewMode] = useState('default');
  const docId = new URLSearchParams(window.location.search).get('doc');
  const urlViewMode = new URLSearchParams(window.location.search).get('viewMode');

  const { presentUsers, currentUserId } = usePresence();

  const currentLead = useMemo(() => {
    return page.props.companies.find(c => c.document_id === docId);
  }, [page.props.companies, docId]);

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
    const params = new URLSearchParams(window.location.search);
    params.delete('doc');
    params.delete('viewMode');
    router.visit('/leads', {
      preserveState: true,
      replace: true,
      preserveScroll: true,
    });
  };

  const copyDocumentLink = () => {
    const url = window.location.host;
    navigator.clipboard.writeText(`${url}/documents/${docId}`);
    toastSuccess('Document link copied', 'document-link-copied');
  };

  return (
    <>
      <ScrollAreaRoot>
        <ScrollAreaViewport>
          <div className="relative w-full h-[calc(100vh-53px)] bg-white px-4 md:px-6">
            <div className="relative bg-white h-full mx-auto  w-full md:min-w-[680px] max-w-[680px]">
              <div className="flex items-center justify-between sticky top-0 bg-white z-10 py-2.5">
                {currentLead && (
                  <div className="flex items-center w-full justify-start gap-2 min-w-0">
                    {currentLead?.icon ? (
                      <img
                        className="size-6 object-contain border border-gray-200 rounded flex-shrink-0"
                        loading="lazy"
                        src={currentLead?.icon}
                        alt="Lead icon"
                      />
                    ) : (
                      <div className="size-6 flex items-center justify-center border border-gray-200 rounded flex-shrink-0">
                        <Icon name="building-06" />
                      </div>
                    )}
                    <p className="text-sm font-medium text-gray-900 truncate">
                      {currentLead?.name} Account Brief
                    </p>
                    {currentLead?.icp_fit === 'strong' && (
                      <div className="bg-error-100 w-fit px-2 py-1 rounded-[4px] max-w-[100px] truncate flex items-center gap-1 flex-shrink-0">
                        <Icon name="flame" className="w-[14px] h-[14px] text-error-500" />
                        <span className="text-error-700 text-xs">Strong fit</span>
                      </div>
                    )}
                  </div>
                )}

                <div className="flex items-center w-full justify-end mb-3 gap-2">
                  {/* <IconButton
                    size="xs"
                    variant="ghost"
                    onClick={() => {
                      if (docId) {
                        window.location.href = `/documents/${docId}/download`;
                      }
                    }}
                    aria-label="download document"
                    icon={<Icon name="download-02" />}
                  /> */}
                  {docId && (
                    <>
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
                        aria-label="copy link"
                        className="hidden md:flex"
                        onClick={copyDocumentLink}
                        icon={<Icon name="link-01" />}
                      />
                    </>
                  )}
                  <IconButton
                    size="xs"
                    variant="ghost"
                    onClick={closeEditor}
                    aria-label="close document"
                    icon={<Icon name="x-close" />}
                  />
                </div>
              </div>

              {docId ? (
                <Editor
                  documentId={docId}
                  useYjs={true}
                  namespace="leads"
                  size="sm"
                  user={presenceUser}
                  key={docId}
                />
              ) : (
                <div className="flex items-center justify-start flex-col h-full">
                  <div className="   flex items-center justify-center">
                    <FeaturedIcon className="mb-6 mt-[40px]">
                      <Icon name="clock-fast-forward" />
                    </FeaturedIcon>
                  </div>
                  <div className="flex flex-col items-center justify-center ">
                    <p className="text-base font-medium mb-1">Preparing account brief</p>
                    <div className="max-w-[340px] text-center gap-2 flex flex-col">
                      <p>
                        We're now busy analyzing and pulling together everything you need to know
                        about this lead.
                      </p>
                      <p>Hang tight, the brief should be available in a moment.</p>
                    </div>
                  </div>
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
