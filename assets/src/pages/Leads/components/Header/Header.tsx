import { useMemo, useState } from 'react';
import { router, usePage } from '@inertiajs/react';

import { Button } from 'src/components/Button';
import { Icon } from 'src/components/Icon/Icon';
import { useEventsChannel, LeadCreatedEvent } from 'src/hooks';
import { UserPresence } from '../UserPresence/UserPresence';
import { Lead, Tenant, User } from 'src/types';
import { PageProps } from '@inertiajs/core';
import {
  ModalBody,
  ModalCloseButton,
  ModalFooter,
  ModalHeader,
  ModalOverlay,
  ModalPortal,
} from 'src/components/Modal/Modal';
import { ModalContent } from 'src/components/Modal/Modal';
import { Modal } from 'src/components/Modal';

const defaultIconSet = [
  'https://images.cust.cx/_companies/img_6qggfu0eyp2ixcillgd5t.jpg',
  'https://images.cust.cx/_companies/img_ml571h9vzoqtykm4r74tc.jpg',
  'https://images.cust.cx/_companies/img_ph7o54ooitopkynfs5p62.jpg',
];

export const Header = () => {
  const [createdLeadIcons, setCreatedLeadIcons] = useState<string[]>([]);
  const page = usePage<PageProps & { tenant: Tenant; currentUser: User; companies: Lead[] }>();
  const [isOpen, setIsOpen] = useState(false);

  const worksspaceLogo = page.props.tenant?.workspace_icon_key;
  const workspaceName = page.props.tenant?.workspace_name;

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
    return createdLeadIcons.slice(0, 3).map((v, index) => (v === '' ? defaultIconSet[index] : v));
  }, [createdLeadIcons]);

  return (
    <>
      <div className="flex w-full relative z-10 bg-white">
        <div className="h-[1px] mb-[-0px] bg-gradient-to-l from-gray-200 to-transparent self-end 2xl:w-[calc((100%-1440px)/2)]" />

        <div className="flex justify-between items-center border-b border-gray-200 w-full 2xl:w-[1440px] 2xl:mx-auto py-2 px-4">
          <div className="flex items-center gap-2 cursor-default">
            {worksspaceLogo ? (
              <img src={worksspaceLogo} alt="Workspace logo" className="size-6 rounded-full" />
            ) : (
              <div className="size-6 rounded-full bg-[url('/images/customeros.png')] bg-cover bg-center" />
            )}
            <h1 className="text-sm font-medium">{workspaceName || 'CustomerOS'}</h1>
          </div>
          <div className="flex gap-2">
            <UserPresence />

            {/* <Button
              leftIcon={<Icon name="rocket-02" />}
              colorScheme="primary"
              size="xs"
              onClick={() => setIsOpen(true)}
            >
              See who's ready to buy
            </Button> */}

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
                <span className="text-sm font-medium text-primary-700">{leadCount} new leads</span>
              </div>
            </div>
          </div>
        )}
      </div>
      <Modal open={isOpen} onOpenChange={setIsOpen}>
        <ModalPortal>
          <ModalOverlay />
          <ModalContent>
            <ModalHeader className="font-semibold text-base">See who's ready to buy</ModalHeader>
            <ModalCloseButton className="absolute top-4 right-4" asChild>
              <Button
                colorScheme="gray"
                size="xs"
                leftIcon={<Icon name="x-close" />}
                variant="ghost"
              />
            </ModalCloseButton>
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
              <ModalCloseButton asChild>
                <Button colorScheme="gray" size="sm" className="w-full">
                  Cancel
                </Button>
              </ModalCloseButton>
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
    </>
  );
};
