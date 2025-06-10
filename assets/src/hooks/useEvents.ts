import { useEffect } from 'react';
import { usePage } from '@inertiajs/react';

import { PageProps } from '@inertiajs/core';
import { Lead, User, Tenant } from 'src/types';

import { useChannel } from './useChannel';

type EventType = 'lead_created' | 'lead_updated';

type Event<K extends EventType = EventType, T extends object = object> = {
  type: K;
  payload: T;
};

export type LeadCreatedEvent = Event<'lead_created', { id: string; icon_url: string }>;

export type LeadUpdatedEvent = Event<'lead_updated', { id: string }>;

export const useEventsChannel = <E extends Event>(onEvent: (event: E) => void) => {
  const page = usePage<PageProps & { tenant: Tenant; currentUser: User; companies: Lead[] }>();
  const tenantId = page.props.tenant.id;
  const { channel } = useChannel(`events:${tenantId}`);

  useEffect(() => {
    if (channel) {
      channel.on('event', (event: E) => {
        onEvent(event);
      });
    }

    return () => {
      channel?.off('event');
    };
  }, [channel, onEvent]);
};
