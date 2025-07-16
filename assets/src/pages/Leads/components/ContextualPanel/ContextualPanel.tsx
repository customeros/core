import { useMemo } from 'react';
import { router, usePage } from '@inertiajs/react';

import axios from 'axios';
import { Icon } from 'src/components/Icon';
import { PageProps } from '@inertiajs/core';
import { Tabs } from 'src/components/Tabs/Tabs';
import { useUrlState } from 'src/hooks/useUrlState';
import { Button } from 'src/components/Button/Button';
import { IconButton } from 'src/components/IconButton';
import { Tooltip } from 'src/components/Tooltip/Tooltip';
import { toastSuccess } from 'src/components/Toast/success';
import { usePresence } from 'src/providers/PresenceProvider';
import {
  Lead,
  User,
  Stage,
  Tenant,
  TargetPersona,
  ChannelAttribution as Attributions,
} from 'src/types';
import {
  ScrollAreaRoot,
  ScrollAreaThumb,
  ScrollAreaViewport,
  ScrollAreaScrollbar,
} from 'src/components/ScrollArea';

import { Engagement } from '../Engagement/Engagement';
import { ContactCard } from '../ContactCard/ContactCard';
import { DocumentEditor } from '../DocumentEditor/DocumentEditor';
import { ChannelAttribution } from '../ChannelAttribution/ChannelAttribution';

export const ContextualPanel = () => {
  const page = usePage<
    PageProps & {
      tenant: Tenant;
      current_user: User;
      personas: TargetPersona[];
      attributions_list: Attributions[];
      leads: Lead[] | Record<Stage, Lead[]>;
    }
  >();
  const params = new URLSearchParams(window.location.search);
  const leadId = params.get('lead');
  // const viewMode = params.get('viewMode');

  const { presentUsers, currentUserId } = usePresence();
  const { getUrlState, setUrlState } = useUrlState();
  const { tab } = getUrlState();

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
    params.delete('tab');
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

  const handleTabClick = (tab: 'account' | 'engagement' | 'contacts') => {
    setUrlState(
      state => {
        return {
          ...state,
          tab,
        };
      },
      {
        revalidate: ['personas', 'attribution', 'attributions_list'],
      }
    );
  };

  const engagementLabel = `Engagements • ${page.props.attributions_list?.length}`;

  const contactsLabel = `Contacts • ${page.props.personas?.length}`;

  return (
    <>
      <ScrollAreaRoot>
        <ScrollAreaViewport>
          <div className="w-full bg-white px-4 md:px-6">
            <div className="relative bg-white h-full mx-auto w-full md:min-w-[680px] max-w-[680px]">
              <div className="flex items-center justify-between sticky top-0 bg-white z-20 py-0.5 ">
                {currentLead && (
                  <div className="flex items-center w-full justify-start gap-2 group/section mt-[5px]">
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
                      {currentLead?.name || 'Unnamed'}
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

                          setUrlState(state => ({
                            ...state,
                            lead: '',
                          }));
                        }}
                      />
                    </Tooltip>
                  </div>
                )}

                <div className="flex items-center w-full justify-end gap-2 ">
                  {currentLead?.document_id && tab === 'account' && (
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
              <div className="w-fit mt-2 mb-4">
                <Tabs variant="enclosed" className="w-fit z-[1]">
                  <Button
                    size="xs"
                    className="w-fit"
                    onClick={() => handleTabClick('account')}
                    data-state={tab === 'account' ? 'active' : 'inactive'}
                  >
                    Account brief
                  </Button>
                  <Button
                    size="xs"
                    className="w-fit"
                    onClick={() => handleTabClick('engagement')}
                    data-state={tab === 'engagement' ? 'active' : 'inactive'}
                  >
                    {engagementLabel}
                  </Button>
                  <Button
                    size="xs"
                    className="w-fit"
                    onClick={() => handleTabClick('contacts')}
                    data-state={tab === 'contacts' ? 'active' : 'inactive'}
                  >
                    {contactsLabel}
                  </Button>
                </Tabs>
              </div>

              {tab === 'account' && (
                <DocumentEditor
                  userId={currentUserId}
                  docId={currentLead?.document_id || ''}
                  presenceUser={presenceUser || { username: '', cursorColor: '' }}
                />
              )}

              {tab === 'engagement' && <Engagement />}

              {tab === 'contacts' && (
                <div className="flex items-center justify-start w-full">
                  <ContactCard />
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
