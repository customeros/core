import clsx from 'clsx';

import { IconButton, IconButtonProps } from 'src/components/IconButton/IconButton';

interface FloatingToolbarButtonProps extends IconButtonProps {
  active?: boolean;
}

export const FloatingToolbarButton = ({
  onClick,
  active,
  icon,
  ...rest
}: FloatingToolbarButtonProps) => {
  return (
    <IconButton
      {...rest}
      size="xs"
      icon={icon}
      variant="ghost"
      onClick={onClick}
      style={{ pointerEvents: 'all' }}
      className={clsx(
        'rounded-sm text-grayModern-100 hover:text-inherit focus:text-inherit hover:bg-grayModern-600 focus:bg-grayModern-600 focus:text-grayModern-100 hover:text-grayModern-100',
        {
          'bg-grayModern-600 text-grayModern-100': active,
        }
      )}
    />
  );
};
