import { usePage } from '@inertiajs/react';
import { useState, useEffect, useContext } from 'react';

import { Presence } from 'phoenix';
import { PageProps } from '@inertiajs/core';

import { User, Tenant } from '../types';
import { PhoenixSocketContext } from '../providers/SocketProvider';

type Meta = {
  color: string;
  phx_ref: string;
  user_id: string;
  username: string;
  online_at: number;
  metadata: { source: string };
};

type PresenceState = { metas: Meta[] }[];

export const useChannel = (channelName: string) => {
  const page = usePage<PageProps & { tenant: Tenant; current_user: User }>();
  const { socket, createChannel, channels } = useContext(PhoenixSocketContext);
  const channel = channels.get(channelName);

  const user_id = (page?.props?.current_user as User)?.id ?? '';
  const username = (page?.props?.current_user as User)?.email;

  useEffect(() => {
    if (!socket || !user_id) return;

    (async () => {
      try {
        await createChannel(channelName, {
          user_id,
          username,
        });
      } catch (err) {
        console.error(err);
      }
    })();

    return () => {
      channel?.leave();
    };
  }, [socket, user_id, username, createChannel, channelName]);

  return { channel };
};

export const usePresenceChannel = (channelName: string) => {
  const { channel } = useChannel(channelName);
  const [presenceState, setPresenceState] = useState<PresenceState | null>(null);

  const presentUsers = parsePresentUsers(presenceState || []);

  useEffect(() => {
    if (!channel) return;
    const presence = new Presence(channel);

    presence.onSync(() => {
      setPresenceState(presence.list());
    });

    return () => {
      channel.leave();
    };
  }, [channel]);

  return { channel, presentUsers };
};

function parsePresentUsers(presenceState: PresenceState) {
  return presenceState.map(p => p.metas?.[0]);
}
