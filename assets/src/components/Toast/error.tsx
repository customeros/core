import { toast } from 'react-toastify';

import { IconButton } from '../IconButton';
import { Icon } from '../Icon/Icon.tsx';

export const toastError = (text: string, id: string) => {
  return toast.error(text, {
    toastId: id,
    icon: <Icon name="alert-circle" className="size-6" />,
    autoClose: 5000,
    closeButton: ({ closeToast }) => (
      <IconButton
        variant="ghost"
        aria-label="Close"
        onClick={closeToast}
        colorScheme="error"
        icon={<Icon name="x-close" />}
      />
    ),
  });
};
