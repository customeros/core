import { usePage } from '@inertiajs/react';
import { ReactNode, useContext, createContext } from 'react';

import { PageProps } from '@inertiajs/core';

import { User, Tenant } from '../types';
import { usePresenceChannel } from '../hooks/useChannel';

type PresenceContextType = {
  currentUserId: string;
  presentUsers: {
    color: string;
    user_id: string;
    username: string;
    online_at: number;
  }[];
};

const PresenceContext = createContext<PresenceContextType>({
  presentUsers: [],
  currentUserId: '',
});

export const usePresence = () => useContext(PresenceContext);

export const PresenceProvider = ({ children }: { children: ReactNode }) => {
  const page = usePage<PageProps & { tenant: Tenant; current_user: User }>();
  const tenant = page.props.tenant as Tenant | undefined;
  const tenantId = tenant?.id;
  const currentUserId = (page?.props?.current_user as User)?.id ?? '';
  const { presentUsers } = usePresenceChannel(tenantId ? `leads:${tenantId}` : '');

  return (
    <PresenceContext.Provider value={{ presentUsers, currentUserId }}>
      {children}
    </PresenceContext.Provider>
  );
};
