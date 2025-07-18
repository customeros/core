import { useEffect } from 'react';
import { ToastContainer } from 'react-toastify';
import { Head, usePage } from '@inertiajs/react';

import posthog from 'posthog-js';
import { PageProps } from '@inertiajs/core';
import { Header } from 'src/pages/Leads/components';
import { User, Lead, Tenant, IcpProfile } from 'src/types';

import { toastError, toastSuccess } from '../components/Toast';
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
  const { props, component } = usePage<
    PageProps & {
      tenant: Tenant;
      companies: Lead[];
      current_user: User;
      page_title?: string;
      profile: IcpProfile;
    }
  >();

  const displayHeader = !['Signin', 'Signup', 'Document'].includes(component);

  useEffect(() => {
    if ('flash' in props) {
      const { flash } = props;

      if ('success' in (flash as Flash)) {
        toastSuccess((flash as Flash).success, 'flash-success');
      }

      if ('error' in (flash as Flash)) {
        toastError((flash as Flash).error, 'flash-error');
      }
    }
  }, [props.flash]);

  useEffect(() => {
    if (props.current_user) {
      // Start Atlas first
      window.Atlas?.call('start');
      // Then identify the user
      window.Atlas?.call('identify', props.current_user.email, {
        email: props.current_user.email,
      });
      posthog?.identify(props.current_user.email);
    }
  }, [props.current_user]);

  return (
    <PhoenixSocketProvider>
      <PresenceProvider>
        <Head>
          <title>{props.page_title || 'CustomerOS'}</title>
        </Head>
        <ToastContainer theme="colored" hideProgressBar={true} position="bottom-right" />
        {displayHeader && <Header />}
        {children}
      </PresenceProvider>
    </PhoenixSocketProvider>
  );
};
