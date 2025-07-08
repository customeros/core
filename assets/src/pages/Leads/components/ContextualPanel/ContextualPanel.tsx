import { useMemo } from 'react';
import { router, usePage } from '@inertiajs/react';

import axios from 'axios';
import { Icon } from 'src/components/Icon';
import { PageProps } from '@inertiajs/core';
import { Tabs } from 'src/components/Tabs/Tabs';
import { useUrlState } from 'src/hooks/useUrlState';
import { Lead, User, Stage, Tenant } from 'src/types';
import { Editor } from 'src/components/Editor/Editor';
import { Button } from 'src/components/Button/Button';
import { IconButton } from 'src/components/IconButton';
import { Tooltip } from 'src/components/Tooltip/Tooltip';
import { toastSuccess } from 'src/components/Toast/success';
import { usePresence } from 'src/providers/PresenceProvider';
import { FeaturedIcon } from 'src/components/FeaturedIcon/FeaturedIcon';
import {
  ScrollAreaRoot,
  ScrollAreaThumb,
  ScrollAreaViewport,
  ScrollAreaScrollbar,
} from 'src/components/ScrollArea';

import { ContactCard } from '../ContactCard/ContactCard';
import { ChannelAttribution } from '../ChannelAttribution/ChannelAttribution';

export const ContextualPanel = () => {
  const page = usePage<
    PageProps & { tenant: Tenant; current_user: User; leads: Lead[] | Record<Stage, Lead[]> }
  >();
  const params = new URLSearchParams(window.location.search);
  const leadId = params.get('lead');
  // const viewMode = params.get('viewMode');

  const { presentUsers, currentUserId } = usePresence();
  const { getUrlState, setUrlState } = useUrlState();
  const { viewDoc } = getUrlState();

  const currentLead = useMemo(() => {
    if (Array.isArray(page.props.leads)) {
      return page.props.leads.find(c => c.id === leadId);
    }

    const leads = page.props.leads as Record<Stage, Lead[]>;
    const targetStage = Object.keys(leads).find(key =>
      leads[key as Stage].some(lead => lead.id === leadId)
    );

    return targetStage ? leads[targetStage as Stage].find(lead => lead.id === leadId) : undefined;
  }, [page.props.leads, leadId]);

  const presenceUser = useMemo(() => {
    const found = presentUsers.find(u => u.user_id === currentUserId);

    if (!found?.username || !found?.color) return undefined;

    return {
      username: found.username,
      cursorColor: found.color,
    };
  }, [currentUserId, presentUsers]);

  // const handleViewModeChange = () => {
  //   const params = new URLSearchParams(window.location.search);
  //   const viewMode = params.get('viewMode');

  //   if (viewMode === 'default') {
  //     params.set('viewMode', 'focus');
  //   } else if (viewMode === 'focus') {
  //     params.set('viewMode', 'default');
  //   } else if (!viewMode) {
  //     params.set('viewMode', 'default');
  //   } else {
  //     params.delete('viewMode');
  //   }

  //   router.get(
  //     '/leads',
  //     {
  //       ...Object.fromEntries(params.entries()),
  //     },
  //     {
  //       only: ['leads'],
  //       replace: true,
  //       preserveState: true,
  //     }
  //   );
  // };

  const closeEditor = () => {
    const params = new URLSearchParams(window.location.search);

    params.delete('lead');
    params.delete('viewMode');
    params.delete('viewDoc');
    router.get(
      '/leads',
      {
        ...Object.fromEntries(params.entries()),
      },
      {
        only: ['leads'],
        replace: true,
        preserveState: true,
      }
    );
  };

  const copyDocumentLink = () => {
    const url = window.location.host;

    navigator.clipboard.writeText(`${url}/documents/${currentLead?.document_id}`);
    toastSuccess('Document link copied', 'document-link-copied');
  };

  const handleTabClick = () => {
    setUrlState(
      state => {
        const newViewDoc = state.viewDoc === 'true' ? 'false' : 'true';

        return {
          ...state,
          viewDoc: newViewDoc,
          viewMode:
            newViewDoc === 'false' && state.viewMode === 'focus' ? 'default' : state.viewMode,
        };
      },
      {
        revalidate: ['personas', 'attribution'],
      }
    );
  };

  return (
    <>
      <ScrollAreaRoot>
        <ScrollAreaViewport>
          <div className="w-full bg-white px-4 md:px-6">
            <div className="relative bg-white h-full mx-auto w-full md:min-w-[680px] max-w-[680px]">
              <div className="flex items-center justify-between sticky top-0 bg-white z-10 py-0.5 mt-[5px]">
                {currentLead && (
                  <div className="flex items-center w-full justify-start gap-2 group/section">
                    {currentLead?.icon ? (
                      <img
                        loading="lazy"
                        alt="Lead icon"
                        src={currentLead?.icon}
                        className="size-6 object-contain border border-gray-200 rounded flex-shrink-0"
                      />
                    ) : (
                      <div className="size-6 flex items-center justify-center border border-gray-200 rounded flex-shrink-0">
                        <Icon name="building-06" />
                      </div>
                    )}
                    <p className="text-[16px] font-medium text-gray-900 truncate w-fit min-w-fit ">
                      {currentLead?.name}
                    </p>
                    {currentLead?.icp_fit === 'strong' && (
                      <div className="bg-error-100 w-fit px-2 py-1.5 rounded-[4px] max-w-[100px] truncate items-center gap-1 flex-shrink-0 hidden sm:flex md:flex lg:flex xl:flex 2xl:flex">
                        <Icon name="flame" className="w-[14px] h-[14px] text-error-500" />
                        <span className="text-error-700 text-xs">Strong fit</span>
                      </div>
                    )}
                    <ChannelAttribution />
                    <Tooltip asChild side="bottom" label="Lead is not a fit">
                      <IconButton
                        size="xs"
                        variant="ghost"
                        aria-label="unqualify-lead"
                        icon={<Icon name="thumbs-down" />}
                        className="group-hover/section:opacity-100 opacity-0 hidden sm:flex md:flex lg:flex xl:flex 2xl:flex"
                        onClick={async e => {
                          e.preventDefault();
                          e.stopPropagation();

                          axios.post(`/leads/${currentLead?.id}/disqualify`).then(() => {
                            toastSuccess(
                              "Noted. We'll tune how we qualify leads.",
                              'lead-disqualified'
                            );
                          });
                        }}
                      />
                    </Tooltip>
                  </div>
                )}

                <div className="flex items-center w-full justify-end gap-2 ">
                  {currentLead?.document_id && viewDoc === 'true' && (
                    <>
                      {/* <Tooltip side="bottom" label="Focus mode">
                        <IconButton
                          size="xs"
                          variant="ghost"
                          className="hidden md:flex"
                          aria-label="toggle view mode"
                          onClick={handleViewModeChange}
                          icon={
                            <Icon name={viewMode === 'default' ? 'expand-01' : 'collapse-01'} />
                          }
                        />
                      </Tooltip> */}

                      <Tooltip side="bottom" label="Copy document link">
                        <IconButton
                          size="xs"
                          variant="ghost"
                          aria-label="copy link"
                          className="hidden md:flex"
                          onClick={copyDocumentLink}
                          icon={<Icon name="link-01" />}
                        />
                      </Tooltip>
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
              <div className="w-fit mt-2">
                <Tabs className="w-fit" variant="enclosed">
                  <Button
                    size="xs"
                    className="w-fit"
                    onClick={handleTabClick}
                    data-state={viewDoc === 'true' ? 'active' : 'inactive'}
                  >
                    Account brief
                  </Button>
                  <Button
                    size="xs"
                    className="w-fit"
                    onClick={handleTabClick}
                    data-state={viewDoc === 'false' ? 'active' : 'inactive'}
                  >
                    Contacts
                  </Button>
                </Tabs>
              </div>

              {viewDoc === 'false' && (
                <div className="flex items-center justify-start w-full">
                  <ContactCard />
                </div>
              )}

              {currentLead?.document_id && viewDoc === 'true' ? (
                <Editor
                  size="sm"
                  useYjs={true}
                  placeholder=""
                  namespace="leads"
                  user={presenceUser}
                  user_id={currentUserId}
                  key={currentLead?.document_id}
                  documentId={currentLead?.document_id}
                />
              ) : (
                viewDoc === 'true' && (
                  <div className="flex items-center justify-start flex-col h-full">
                    <div className="flex items-center justify-center">
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
                )
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
