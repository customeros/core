import React from 'react';
import { Icon } from '../Icon/Icon';
import { Button } from '../Button/Button';
import clsx from 'clsx';

interface SegmentedViewProps {
  icon: React.ReactNode;
  label: string;
  count: number;
  className?: string;
  isSelected: boolean;
  onClick: () => void;
  handleClearFilter: () => void;
}

export const SegmentedView = ({
  icon,
  label,
  count,
  onClick,
  className,
  isSelected,
  handleClearFilter,
}: SegmentedViewProps) => {
  if (count === 0) return null;
  return (
    <div
      className={clsx(
        'flex w-full py-1 bg-gray-100 items-center justify-between mx-auto md:rounded-[4px] px-6',
        className
      )}
    >
      <div className="flex items-center space-x-3 h-[30px] cursor-pointer" onClick={onClick}>
        <div className="flex-shrink-0 mb-[2px]">{icon}</div>
        <h3 className="font-medium">{label}</h3>
        <p className="text-gray-700"> {count}</p>
      </div>
      {isSelected && (
        <Button
          colorScheme="gray"
          variant="ghost"
          size="xxs"
          leftIcon={<Icon name="x-close" />}
          onClick={handleClearFilter}
        >
          Clear filter
        </Button>
      )}
    </div>
  );
};
