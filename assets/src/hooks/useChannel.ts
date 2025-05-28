import type { Channel } from 'phoenix';

import { useState, useEffect, useContext } from 'react';

import { Presence } from 'phoenix';
import { usePage } from '@inertiajs/react';
import { PhoenixSocketContext } from '../providers/SocketProvider';

type Meta = {
  color: string;
  phx_ref: string;
  user_id: string;
  username: string;
  online_at: number;
  metadata: { source: string };
};
type PresenceDiff = {
  [key: string]: {
    metas: Meta[];
  };
};

type PresenceState = { metas: Meta[] }[];

type User = { email: string; id: string; name: string };

export const useChannel = (channelName: string) => {
  const { socket } = useContext(PhoenixSocketContext);
  const page = usePage();
  const [presenceState, setPresenceState] = useState<PresenceState | null>(null);

  const [channel, setChannel] = useState<Channel | null>(null);
  const [presence, setPresence] = useState<PresenceDiff | null>(null);
  const presentUsers = parsePresentUsers(presenceState || []);

  const user_id = (page?.props?.currentUser as User)?.id ?? '';
  const username = (page?.props?.currentUser as User)?.email;

  useEffect(() => {
    if (!socket || !user_id) return;

    if (channel?.state === 'joined') {
      channel.leave();
    }

    const phoenixChannel = socket?.channel(channelName, {
      user_id,
      username,
    });

    if (!phoenixChannel) return;

    phoenixChannel
      ?.join()
      ?.receive('ok', () => {
        setChannel(phoenixChannel);
      })
      .receive('error', () => {
        // TODO: handle error
      });

    const presence = new Presence(phoenixChannel);

    presence.onSync(() => {
      setPresenceState(presence.list());
    });

    return () => {
      phoenixChannel.leave();
    };
  }, [setPresence, socket, user_id, username]);

  return { channel, presence, presentUsers, currentUserId: user_id };
};

function parsePresentUsers(presenceState: PresenceState) {
  return presenceState.map(p => p.metas?.[0]);
}
