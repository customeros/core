import { useEffect } from 'react';
import { usePage } from '@inertiajs/react';
import { cssTransition, ToastContainer } from 'react-toastify';

import posthog from 'posthog-js';
import { PageProps } from '@inertiajs/core';
import { User, Lead, Tenant, IcpProfile } from 'src/types';

import { toastSuccess } from '../components/Toast';
import { PresenceProvider } from '../providers/PresenceProvider';
import { PhoenixSocketProvider } from '../providers/SocketProvider';

type FlashType = 'error' | 'success';

type Flash = {
  [K in FlashType]: string;
};

// Define Atlas window interface
declare global {
  interface Window {
    Atlas?: {
      call: (method: string, ...args: unknown[]) => void;
    };
  }
}

export const RootLayout = ({ children }: { children: React.ReactNode }) => {
  const { props } = usePage<
    PageProps & { tenant: Tenant; currentUser: User; companies: Lead[]; profile: IcpProfile }
  >();

  useEffect(() => {
    if ('flash' in props) {
      const { flash } = props;

      if ('success' in (flash as Flash)) {
        toastSuccess((flash as Flash).success, 'flash-success');
      }
    }
  }, [props.flash]);

  useEffect(() => {
    if (props.currentUser) {
      // Start Atlas first
      window.Atlas?.call('start');
      // Then identify the user
      window.Atlas?.call('identify', props.currentUser.email, {
        email: props.currentUser.email,
      });
      posthog?.identify(props.currentUser.email);
    }
  }, [props.currentUser]);

  return (
    <PhoenixSocketProvider>
      <PresenceProvider>
        <ToastContainer
          limit={3}
          theme="colored"
          autoClose={8000}
          closeOnClick={true}
          hideProgressBar={true}
          position="bottom-right"
          transition={cssTransition({
            enter: 'animate-slideDownAndFade',
            exit: 'animate-fadeOut',
            collapse: false,
          })}
        />
        {children}
      </PresenceProvider>
    </PhoenixSocketProvider>
  );
};
