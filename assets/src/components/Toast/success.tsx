import { toast } from 'react-toastify';

import { Icon } from '../Icon';
import { IconButton } from '../IconButton';

export const toastSuccess = (text: string, id: string) => {
  return toast.success(text, {
    toastId: id,
    icon: <Icon className="size-6" name="check-circle" />,
    closeButton: ({ closeToast }) => (
      <IconButton
        size="xs"
        variant="ghost"
        aria-label="Close"
        className="ml-auto"
        onClick={closeToast}
        colorScheme="success"
        icon={<Icon name="x-close" />}
      />
    ),
  });
};
