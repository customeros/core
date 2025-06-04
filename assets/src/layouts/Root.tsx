import { useEffect } from 'react';
import { useForm, usePage } from '@inertiajs/react';
import { cssTransition, ToastContainer } from 'react-toastify';
import { toastSuccess, toastError } from '../components/Toast';
import { PhoenixSocketProvider } from '../providers/SocketProvider';
import { PresenceProvider } from '../providers/PresenceProvider';

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
