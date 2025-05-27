import { useState, useEffect, createContext } from 'react';

import { Socket } from 'phoenix';

const PhoenixSocketContext = createContext<{ socket: Socket | null }>({
  socket: null,
});

const PhoenixSocketProvider = ({ children }: { children: React.ReactNode }) => {
  const [socket, setSocket] = useState<Socket | null>(null);

  const socketPath = '/socket';

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
    <PhoenixSocketContext.Provider value={{ socket }}>{children}</PhoenixSocketContext.Provider>
  );
};

export { PhoenixSocketContext, PhoenixSocketProvider };
