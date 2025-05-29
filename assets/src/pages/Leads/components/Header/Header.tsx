import { useMemo, useState } from 'react';
import { router, usePage } from '@inertiajs/react';

import { Button } from 'src/components/Button';
import { Icon } from 'src/components/Icon/Icon';
import { useEventsChannel, LeadCreatedEvent } from 'src/hooks';
import { UserPresence } from '../UserPresence/UserPresence';
import { Tenant } from 'src/types';

export const Header = () => {
  const [createdLeadIcons, setCreatedLeadIcons] = useState<string[]>([]);
  const page = usePage();
  const tenantId = (page.props.tenant as Tenant).id;
  useEventsChannel<LeadCreatedEvent>(event => {
    if (event.type === 'lead_created') {
      console.log(event);
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
    return createdLeadIcons.slice(0, 3);
  }, [createdLeadIcons]);

  return (
    <div className="flex w-full relative">
      <div className="h-[1px] mb-[-0px] bg-gradient-to-l from-gray-200 to-transparent self-end 2xl:w-[calc((100%-1440px)/2)]" />

      <div className="flex justify-between items-center border-b border-gray-200 w-full 2xl:w-[1440px] 2xl:mx-auto py-2 px-4">
        <h1 className="">Leads</h1>
        <div className="flex gap-2">
          <UserPresence />
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
            {headIcons.map((icon, index) => (
              <img
                key={icon}
                src={icon}
                alt="Lead icon"
                className="size-4 rounded-full shadow-sm"
                style={{ zIndex: 10000 + index, marginLeft: index > 0 ? -16 : 0 }}
              />
            ))}
            <div className="flex flex-col">
              <span className="text-sm font-medium text-primary-700">{leadCount} new leads</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
