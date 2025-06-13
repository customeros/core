import { useMemo, useState } from 'react';
import { router, usePage } from '@inertiajs/react';

import { cn } from 'src/utils/cn';
import { PageProps } from '@inertiajs/core';
import { Button } from 'src/components/Button';
import { Toggle } from 'src/components/Toggle';
import { Avatar } from 'src/components/Avatar';
import { Select } from 'src/components/Select';
import { Icon } from 'src/components/Icon/Icon';
import { Tooltip } from 'src/components/Tooltip';
import { toastSuccess } from 'src/components/Toast';
import { IconButton } from 'src/components/IconButton';
import { Lead, User, Tenant, Profile, UrlState } from 'src/types';
import { useUrlState, useEventsChannel, LeadCreatedEvent } from 'src/hooks';
import { Popover, PopoverContent, PopoverTrigger } from 'src/components/Popover';
import {
  Modal,
  ModalBody,
  ModalClose,
  ModalFooter,
  ModalHeader,
  ModalPortal,
  ModalOverlay,
  ModalContent,
  ModalScrollBody,
  ModalCloseButton,
} from 'src/components/Modal/Modal';

import { TenantSwitcher } from '../TenantSwitcher';
import { UserPresence } from '../UserPresence/UserPresence';

const orderByOptions = [
  { label: 'Created', value: 'inserted_at' },
  { label: 'Name', value: 'name' },
  { label: 'Industry', value: 'industry' },
  { label: 'Stage', value: 'stage' },
  { label: 'Country', value: 'country' },
];

export const Header = () => {
  const [createdLeadIcons, setCreatedLeadIcons] = useState<string[]>([]);
  const page = usePage<
    PageProps & {
      leads: Lead[];
      tenant: Tenant;
      profile: Profile;
      maxCount: number;
      currentUser: User;
    }
  >();
  const [isOpen, setIsOpen] = useState(false);
  const [displayProfile, setDisplayProfile] = useState(false);
  const [inviteTeam, setInviteTeam] = useState(false);
  const worksspaceLogo = page.props.tenant?.workspace_icon_key;
  const workspaceName = page.props.tenant?.workspace_name;
  const domain = page.props.tenant?.domain;

  const { getUrlState, setUrlState } = useUrlState<UrlState>({ revalidate: ['leads'] });

  const { pipeline, desc, asc, group } = getUrlState();
  const orderBy = desc || asc;

  useEventsChannel<LeadCreatedEvent>(event => {
    if (event.type === 'lead_created') {
      setCreatedLeadIcons(prev => [...prev, event.payload.icon_url]);
    }
  });

  const handleClick = () => {
    setCreatedLeadIcons([]);
    router.visit('/leads', {
      only: ['leads'],
    });
  };

  const leadCount = useMemo(() => {
    return createdLeadIcons.length;
  }, [createdLeadIcons]);

  const headIcons = useMemo(() => {
    return createdLeadIcons.slice(0, 3).filter(Boolean);
  }, [createdLeadIcons]);

  const leadsMessage = leadCount > 1 ? 'leads' : 'lead';

  return (
    <>
      <div className="flex w-full z-20 bg-white sticky top-0 group">
        <div className="h-[1px] mb-[-0px] bg-gradient-to-l from-gray-200 to-transparent self-end 2xl:w-[calc((100%-1440px)/2)]" />

        <div className="flex justify-between items-center border-b border-gray-200 w-full 2xl:w-[1440px] 2xl:mx-auto py-2 px-4">
          <div className="flex items-center gap-2">
            <TenantSwitcher
              currentTenant={page.props.tenant.id}
              isAdmin={page.props.currentUser.admin}
            >
              <div
                className={cn(
                  'flex items-center gap-2 cursor-pointer',
                  !page.props.currentUser.admin && 'cursor-default'
                )}
              >
                {worksspaceLogo ? (
                  <img src={worksspaceLogo} alt="Workspace logo" className="size-6 rounded-full" />
                ) : (
                  <div className="size-6 rounded-full bg-[url('/images/customeros.png')] bg-cover bg-center" />
                )}
                <h1 className="text-sm font-medium">{workspaceName || 'CustomerOS'}</h1>
              </div>
            </TenantSwitcher>
            <IconButton
              size="xs"
              variant="ghost"
              aria-label="icp"
              icon={<Icon name="building-03" />}
              onClick={e => {
                page.props.profile && setDisplayProfile(true);
                e.stopPropagation();
              }}
              className="group-hover:opacity-100 opacity-100 sm:opacity-0 md:opacity-0 lg:opacity-0 xl:opacity-0 2xl:opacity-0 transition-opacity duration-300"
            />
          </div>

          <div className="flex items-center gap-2">
            <Tooltip label="Invite team">
              <div onClick={() => setInviteTeam(true)}>
                <Avatar
                  size="xs"
                  variant="circle"
                  icon={<Icon name="user-plus-01" className="text-gray-700 size-5 p-0.5" />}
                  className="border border-dashed group-hover:opacity-100 pacity-100 sm:opacity-0 md:opacity-0 lg:opacity-0 xl:opacity-0 2xl:opacity-0 transition-opacity duration-300 size-7 cursor-pointer"
                />
              </div>
            </Tooltip>
            <UserPresence />

            {/* <Button
              leftIcon={<Icon name="rocket-02" />}
              colorScheme="primary"
              size="xs"
              onClick={() => setIsOpen(true)}
            >
              See who's ready to buy
            </Button> */}
            <Popover>
              <PopoverTrigger asChild>
                <Button
                  size="xs"
                  variant="ghost"
                  colorScheme="gray"
                  leftIcon={<Icon name="distribute-spacing-vertical" />}
                >
                  Display
                </Button>
              </PopoverTrigger>
              <PopoverContent className="flex flex-col gap-2 w-[221px]">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Icon name="recording-01" />
                    <span>Pipeline</span>
                  </div>

                  <Toggle
                    size="sm"
                    isChecked={pipeline !== 'hidden'}
                    onChange={value => {
                      setUrlState(params => ({
                        ...params,
                        pipeline: value ? 'visible' : 'hidden',
                      }));
                    }}
                  />
                </div>

                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Icon name="rows-01" />
                    <span>Grouping</span>
                  </div>

                  <Toggle
                    size="sm"
                    isChecked={group === 'stage'}
                    onChange={value => {
                      setUrlState(params => ({
                        ...params,
                        group: value ? 'stage' : undefined,
                      }));
                    }}
                  />
                </div>

                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <Icon name="arrow-switch-vertical-01" />
                    <span>Ordering</span>
                  </div>

                  <div className="w-fit flex items-center gap-2">
                    <Select
                      size="xxs"
                      menuWidth="fit-item"
                      isSearchable={false}
                      placeholder="Order by"
                      options={orderByOptions}
                      value={orderByOptions.find(option => option.value === orderBy) || null}
                      onChange={value => {
                        setUrlState(({ desc, asc, ...rest }) => {
                          if (value.value === desc || value.value === asc) {
                            return rest;
                          }

                          return {
                            ...rest,
                            desc: value.value,
                          };
                        });
                      }}
                    />

                    <IconButton
                      size="xxs"
                      aria-label="icp"
                      variant="outline"
                      icon={<Icon name={desc ? 'arrows-down' : 'arrows-up'} />}
                      onClick={() => {
                        setUrlState(({ desc, asc, ...rest }) => {
                          if (desc && asc) {
                            return {
                              ...rest,
                            };
                          }

                          if (desc) {
                            return {
                              ...rest,
                              asc: desc,
                            };
                          }

                          if (asc) {
                            return {
                              ...rest,
                              desc: asc,
                            };
                          }

                          return {
                            ...rest,
                            desc: 'inserted_at',
                          };
                        });
                      }}
                    />
                  </div>
                </div>
              </PopoverContent>
            </Popover>
            {page.props.maxCount > 0 && (
              <Button
                size="xs"
                colorScheme="gray"
                leftIcon={<Icon name="download-02" />}
                onClick={() => {
                  window.location.href = '/leads/download';
                }}
              >
                Download
              </Button>
            )}
          </div>
        </div>

        <div className="h-[1px] mb-[-0px] bg-gradient-to-r from-gray-200 to-transparent self-end 2xl:w-[calc((100%-1440px)/2)]" />

        {createdLeadIcons.length > 0 && (
          <div
            onClick={handleClick}
            className="fixed top-[20px] left-1/2 transform -translate-x-1/2 z-[10000] px-4 py-3 rounded-full bg-white shadow-lg cursor-pointer"
          >
            <div className="flex items-center gap-2">
              {headIcons.map((icon, index) =>
                icon ? (
                  <img
                    key={icon}
                    src={icon}
                    alt="Lead icon"
                    className="size-4 rounded-full shadow-sm"
                    style={{ zIndex: 10000 + index, marginLeft: index > 0 ? -16 : 0 }}
                  />
                ) : (
                  <div
                    className="size-4 rounded-full shadow-sm bg-gray-200"
                    style={{ zIndex: 10000 + index, marginLeft: index > 0 ? -16 : 0 }}
                  >
                    <Icon name="building-06" className="size-2" />
                  </div>
                )
              )}
              <div className="flex flex-col">
                <span className="text-sm font-medium text-primary-700">
                  {leadCount} new {leadsMessage}
                </span>
              </div>
            </div>
          </div>
        )}
      </div>
      <Modal open={isOpen} onOpenChange={setIsOpen}>
        <ModalPortal>
          <ModalOverlay />
          <ModalContent placement="top">
            <ModalScrollBody>
              <ModalHeader className="font-semibold text-base">See who's ready to buy</ModalHeader>
              <ModalClose />
              <ModalBody className="flex flex-col gap-2">
                <p>
                  To know where your leads are in their journey and who's ready to buy, let's help
                  you set up our simple web tracker.
                </p>
                <p>
                  Once set up, we'll automatically fill your pipeline with highly-qualified leads,
                  enriched with intent signals.
                </p>
              </ModalBody>
              <ModalFooter className="flex justify-between gap-2">
                <ModalClose asChild>
                  <Button size="sm" colorScheme="gray" className="w-full">
                    Cancel
                  </Button>
                </ModalClose>
                <Button
                  size="sm"
                  className="w-full"
                  colorScheme="primary"
                  onClick={() => {
                    window.open('https://cal.com/mbrown/20min', '_blank');
                    setIsOpen(false);
                  }}
                >
                  Book a call
                </Button>
              </ModalFooter>
            </ModalScrollBody>
          </ModalContent>
        </ModalPortal>
      </Modal>

      <Modal open={displayProfile} onOpenChange={setDisplayProfile}>
        <ModalPortal>
          <ModalOverlay />
          <ModalContent
            placement="top"
            aria-describedby="profile-modal"
            className="max-h-[90vh] overflow-y-auto"
          >
            <ModalHeader className="font-semibold text-base sticky top-0 bg-white ">
              <div className="flex flex-col items-start gap-2">
                <p className="font-semibold">Your Ideal Customer Profile</p>
              </div>
              <ModalCloseButton />
            </ModalHeader>
            <ModalBody className="flex flex-col gap-2">
              <p className="font-medium text-sm">Description</p>

              <p className="mb-4">{page.props?.profile?.profile}</p>
              <p className="text-sm font-medium">Qualifying criteria</p>
              <ul className="list-disc pl-4 flex flex-col gap-0 text-sm">
                {page.props?.profile?.qualifying_attributes?.map(attribute => (
                  <li key={attribute}>{attribute}</li>
                ))}
              </ul>
            </ModalBody>
            <ModalFooter className="sticky bottom-0 bg-white">
              <ModalClose asChild>
                <Button size="sm" colorScheme="gray" className="w-full">
                  Cancel
                </Button>
              </ModalClose>
            </ModalFooter>
          </ModalContent>
        </ModalPortal>
      </Modal>

      <Modal open={inviteTeam} onOpenChange={setInviteTeam}>
        <ModalPortal>
          <ModalOverlay />
          <ModalContent
            placement="top"
            aria-describedby="profile-modal"
            className="max-h-[90vh] overflow-y-auto"
          >
            <ModalHeader className="font-semibold text-base">
              Unlimited seats, unlimited collaboration
            </ModalHeader>
            <ModalCloseButton />
            <ModalBody className="flex flex-col gap-2">
              <p>SaaS is a team sport, but most tools still keep us stuck in silos.</p>
              <p>
                CustomerOS gives every workspace{' '}
                <span className="font-semibold">unlimited seats</span>, so your whole team can work
                together without barriers.
              </p>
              <p>
                To invite your team, just share the app with anyone using a{' '}
                <span className="font-medium">{domain} </span>
                email.
              </p>
            </ModalBody>
            <ModalFooter className="flex justify-between gap-2">
              <Button
                size="sm"
                colorScheme="gray"
                className="w-full"
                onClick={() => {
                  navigator.clipboard.writeText(window.location.href);
                  toastSuccess('App link copied, now share it with your team', 'app-link-copied');
                  setInviteTeam(false);
                }}
              >
                Copy app link
              </Button>
            </ModalFooter>
          </ModalContent>
        </ModalPortal>
      </Modal>
    </>
  );
};
