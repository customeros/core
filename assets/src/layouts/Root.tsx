import { useEffect } from 'react';
import { usePage } from '@inertiajs/react';
import { cssTransition, ToastContainer } from 'react-toastify';

import { AtlasProvider } from 'src/providers/AtlasProvider';
import { PostHogProvider } from 'src/providers/PostHogProvider';

import { toastSuccess } from '../components/Toast';
import { PresenceProvider } from '../providers/PresenceProvider';
import { PhoenixSocketProvider } from '../providers/SocketProvider';

type FlashType = 'error' | 'success';

type Flash = {
  [K in FlashType]: string;
};

export const RootLayout = ({ children }: { children: React.ReactNode }) => {
  const { props } = usePage();

  useEffect(() => {
    if ('flash' in props) {
      const { flash } = props;

      if ('success' in (flash as Flash)) {
        toastSuccess((flash as Flash).success, 'flash-success');
      }
    }
  }, [props.flash]);

  return (
    <PhoenixSocketProvider>
      <PresenceProvider>
        <PostHogProvider>
          <AtlasProvider>
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
          </AtlasProvider>
        </PostHogProvider>
      </PresenceProvider>
    </PhoenixSocketProvider>
  );
};
