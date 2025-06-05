import { toast } from 'react-toastify';

import { IconButton } from '../IconButton';
import { Icon } from '../Icon';

export const toastSuccess = (text: string, id: string) => {
  return toast.success(text, {
    toastId: id,
    icon: <Icon name="alert-circle" className="size-6" />,
    autoClose: 5000,
    closeButton: ({ closeToast }) => (
      <IconButton
        variant="ghost"
        size="xs"
        aria-label="Close"
        colorScheme="success"
        className="ml-auto"
        onClick={closeToast}
        icon={<Icon name="x-close" />}
      />
    ),
  });
};
