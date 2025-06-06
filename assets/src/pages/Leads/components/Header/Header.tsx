import { useMemo, useState } from 'react';
import { router, usePage } from '@inertiajs/react';

import { Button } from 'src/components/Button';
import { Icon } from 'src/components/Icon/Icon';
import { useEventsChannel, LeadCreatedEvent } from 'src/hooks';
import { UserPresence } from '../UserPresence/UserPresence';
import { Lead, Tenant, User } from 'src/types';
import { PageProps } from '@inertiajs/core';
import {
  Modal,
  ModalBody,
  ModalCloseButton,
  ModalFooter,
  ModalHeader,
  ModalOverlay,
  ModalPortal,
  ModalContent,
  ModalClose,
} from 'src/components/Modal/Modal';
import { cn } from 'src/utils/cn';
import { Avatar } from 'src/components/Avatar';
import { Tooltip } from 'src/components/Tooltip';
import { toastSuccess } from 'src/components/Toast';
import { IconButton } from 'src/components/IconButton';

const defaultIconSet = [
  'https://images.cust.cx/_companies/img_6qggfu0eyp2ixcillgd5t.jpg',
  'https://images.cust.cx/_companies/img_ml571h9vzoqtykm4r74tc.jpg',
  'https://images.cust.cx/_companies/img_ph7o54ooitopkynfs5p62.jpg',
];

export const Header = () => {
  const [createdLeadIcons, setCreatedLeadIcons] = useState<string[]>([]);
  const page = usePage<
    PageProps & { tenant: Tenant; currentUser: User; companies: Lead[]; profile: string }
  >();
  const [isOpen, setIsOpen] = useState(false);
  const [displayProfile, setDisplayProfile] = useState(false);
  const [inviteTeam, setInviteTeam] = useState(false);
  console.log(page.props);
  const worksspaceLogo = page.props.tenant?.workspace_icon_key;
  const workspaceName = page.props.tenant?.workspace_name;
  const domain = page.props.tenant?.domain;

  useEventsChannel<LeadCreatedEvent>(event => {
    if (event.type === 'lead_created') {
      setCreatedLeadIcons(prev => [...prev, event.payload.icon_url]);
    }
  });

  const handleClick = () => {
    setCreatedLeadIcons([]);
    router.visit('/leads', {
      only: ['companies'],
    });
  };

  const leadCount = useMemo(() => {
    return createdLeadIcons.length;
  }, [createdLeadIcons]);

  const headIcons = useMemo(() => {
    return createdLeadIcons.slice(0, 3).map((v, index) => v || defaultIconSet[index]);
  }, [createdLeadIcons]);

  const leadsMessage = leadCount > 1 ? 'leads' : 'lead';
  return (
    <>
      <div className="flex w-full z-20 bg-white sticky top-0 group">
        <div className="h-[1px] mb-[-0px] bg-gradient-to-l from-gray-200 to-transparent self-end 2xl:w-[calc((100%-1440px)/2)]" />

        <div className="flex justify-between items-center border-b border-gray-200 w-full 2xl:w-[1440px] 2xl:mx-auto py-2 px-4">
          <div
            className={cn('flex items-center gap-2 cursor-default', {
              'cursor-pointer': page.props.profile,
            })}
            onClick={() => page.props.profile && setDisplayProfile(true)}
          >
            {worksspaceLogo ? (
              <img src={worksspaceLogo} alt="Workspace logo" className="size-6 rounded-full" />
            ) : (
              <div className="size-6 rounded-full bg-[url('/images/customeros.png')] bg-cover bg-center" />
            )}
            <h1 className="text-sm font-medium">{workspaceName || 'CustomerOS'}</h1>
          </div>
          <div className="flex items-center gap-2">
            <Tooltip label="Invite team">
              <div onClick={() => setInviteTeam(true)}>
                <Avatar
                  icon={<Icon name="user-plus-01" className="text-gray-700 size-5 p-0.5" />}
                  size="xs"
                  variant="circle"
                  className="border border-dashed group-hover:opacity-100 opacity-0 transition-opacity duration-300 size-7 cursor-pointer"
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
            {page.props.companies.length > 0 && (
              <Button
                colorScheme="gray"
                size="xs"
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
            className="absolute top-[120px] left-1/2 transform -translate-x-1/2 z-[10000] px-4 py-3 rounded-full bg-white shadow-lg cursor-pointer"
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
            <ModalHeader className="font-semibold text-base">See who's ready to buy</ModalHeader>
            <ModalClose />
            <ModalBody className="flex flex-col gap-2">
              <p>
                To know where your leads are in their journey and who's ready to buy, let's help you
                set up our simple web tracker.
              </p>
              <p>
                Once set up, we'll automatically fill your pipeline with highly-qualified leads,
                enriched with intent signals.
              </p>
            </ModalBody>
            <ModalFooter className="flex justify-between gap-2">
              <ModalClose asChild>
                <Button colorScheme="gray" size="sm" className="w-full">
                  Cancel
                </Button>
              </ModalClose>
              <Button
                colorScheme="primary"
                size="sm"
                className="w-full"
                onClick={() => {
                  window.open('https://cal.com/mbrown/20min', '_blank');
                  setIsOpen(false);
                }}
              >
                Book a call
              </Button>
            </ModalFooter>
          </ModalContent>
        </ModalPortal>
      </Modal>

      <Modal open={displayProfile} onOpenChange={setDisplayProfile}>
        <ModalPortal>
          <ModalOverlay />
          <ModalContent placement="top" aria-describedby="profile-modal">
            <ModalHeader className="font-semibold text-base">See who's ready to buy</ModalHeader>
            <ModalCloseButton />
            <ModalBody className="flex flex-col gap-2">
              <p>{page.props?.profile}</p>
            </ModalBody>
            <ModalFooter>
              <ModalClose asChild>
                <Button colorScheme="gray" size="sm" className="w-full">
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
          <ModalContent placement="top" aria-describedby="profile-modal">
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
                colorScheme="gray"
                size="sm"
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
