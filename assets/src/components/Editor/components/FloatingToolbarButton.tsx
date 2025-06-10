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
        'rounded-sm text-gray-100 hover:bg-gray-600 focus:bg-gray-600 focus:text-gray-100 hover:text-gray-100',
        {
          'bg-gray-600 text-gray-100': active,
        }
      )}
    />
  );
};
