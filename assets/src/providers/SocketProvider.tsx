import { useState, useEffect, createContext, useCallback } from 'react';

import { Channel, Socket } from 'phoenix';

const PhoenixSocketContext = createContext<{
  socket: Socket | null;
  createChannel: (channelName: string, attrs: Record<string, any>) => Promise<Channel | null>;
  channels: Map<string, Channel>;
}>({
  socket: null,
  createChannel: () => null as unknown as Promise<Channel | null>,
  channels: new Map(),
});

const channelPromise = (
  socket: Socket,
  channelName: string,
  attrs: Record<string, any>
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
    async (channelName: string, attrs: Record<string, any>) => {
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
    [socket, setChannels]
  );

  useEffect(() => {
    try {
      const socket = new Socket(socketPath);

      socket.connect();
      setSocket(socket);
    } catch (e) {
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
