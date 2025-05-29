import { createContext, useContext, ReactNode } from 'react';
import { useChannel } from '../hooks/useChannel';
import { usePage } from '@inertiajs/react';
import { Tenant } from '../types';

type PresenceContextType = {
  presentUsers: {
    user_id: string;
    username: string;
    color: string;
    online_at: number;
  }[];
  currentUserId: string;
};

const PresenceContext = createContext<PresenceContextType>({
  presentUsers: [],
  currentUserId: '',
});

export const usePresence = () => useContext(PresenceContext);

export const PresenceProvider = ({ children }: { children: ReactNode }) => {
  const page = usePage();
  const tenant = page.props.tenant as Tenant | undefined;
  const tenantId = tenant?.id;
  const { presentUsers, currentUserId } = useChannel(tenantId ? `leads:${tenantId}` : '');

  return (
    <PresenceContext.Provider value={{ presentUsers, currentUserId }}>
      {children}
    </PresenceContext.Provider>
  );
};
