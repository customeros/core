import { useEffect } from 'react';
import { usePage } from '@inertiajs/react';

import { PageProps } from '@inertiajs/core';
import { Lead, User, Stage, Tenant } from 'src/types';

import { useChannel } from './useChannel';

type EventType = 'lead_created' | 'lead_updated' | 'icp_fit_evaluation_complete';

type Event<K extends EventType = EventType, T extends object = object> = {
  type: K;
  payload: T;
};

export type LeadCreatedEvent = Event<
  'lead_created',
  { id: string; icon_url: string; stage: Exclude<Stage, 'customer'> }
>;

export type LeadUpdatedEvent = Event<'lead_updated', { id: string }>;

export type IcpFitEvaluationCompleteEvent = Event<
  'icp_fit_evaluation_complete',
  { is_fit: boolean }
>;

export const useEventsChannel = <E extends Event>(
  onEvent: (event: E) => void,
  channelName?: string
) => {
  const page = usePage<PageProps & { tenant: Tenant; companies: Lead[]; current_user: User }>();
  const tenantId = page.props.tenant?.id;
  const { channel } = useChannel(`events:${channelName ?? tenantId}`);

  useEffect(() => {
    if (!channel) return;

    const handleEvent = (event: E) => {
      onEvent(event);
    };

    const listener = channel.on('event', handleEvent);

    return () => {
      channel.off('event', listener);
    };
  }, [channel, onEvent]);
};
