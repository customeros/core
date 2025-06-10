import { toast } from 'react-toastify';

import { Icon } from '../Icon/Icon.tsx';
import { IconButton } from '../IconButton';

export const toastError = (text: string, id: string) => {
  return toast.error(text, {
    toastId: id,
    icon: <Icon className="size-6" name="alert-circle" />,
    autoClose: 5000,
    closeButton: ({ closeToast }) => (
      <IconButton
        variant="ghost"
        aria-label="Close"
        className="ml-auto"
        colorScheme="error"
        onClick={closeToast}
        icon={<Icon name="x-close" className="size-4" />}
      />
    ),
  });
};
