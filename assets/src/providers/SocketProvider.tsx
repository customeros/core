import { useState, useEffect, useCallback, createContext } from 'react';

import { Socket, Channel } from 'phoenix';

const PhoenixSocketContext = createContext<{
  socket: Socket | null;
  channels: Map<string, Channel>;
  createChannel: (channelName: string, attrs: Record<string, unknown>) => Promise<Channel | null>;
}>({
  socket: null,
  createChannel: () => null as unknown as Promise<Channel | null>,
  channels: new Map(),
});

const channelPromise = (
  socket: Socket,
  channelName: string,
  attrs: Record<string, unknown>
): Promise<Channel | null> => {
  return new Promise((resolve, reject) => {
    const channel = socket?.channel(channelName, attrs);

    channel
      ?.join()
      .receive('ok', () => {
        resolve(channel);
      })
      .receive('error', () => {
        reject(new Error('Failed to join channel'));
      });
  });
};

const PhoenixSocketProvider = ({ children }: { children: React.ReactNode }) => {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [channels, setChannels] = useState<Map<string, Channel>>(new Map());

  const socketPath = '/socket';

  const createChannel = useCallback(
    async (channelName: string, attrs: Record<string, unknown>) => {
      if (!socket) return null;

      if (channels.has(channelName)) {
        return channels.get(channelName) as Channel;
      }

      const channel = await channelPromise(socket, channelName, attrs);

      if (!channel) return null;

      setChannels(prev => {
        prev.set(channelName, channel);

        return new Map(prev);
      });

      return channels.get(channelName) as Channel;
    },
    [socket, channels]
  );

  useEffect(() => {
    try {
      const socket = new Socket(socketPath);

      socket.connect();

      setSocket(socket);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('error connecting to socket', e);
      // TODO: log error
    }
  }, [socketPath]);

  return (
    <PhoenixSocketContext.Provider value={{ socket, createChannel, channels }}>
      {children}
    </PhoenixSocketContext.Provider>
  );
};

export { PhoenixSocketContext, PhoenixSocketProvider };
