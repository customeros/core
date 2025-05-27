import React from 'react';
import { Icon } from '../Icon/Icon';
import { Button } from '../Button/Button';

interface SegmentedViewProps {
  icon: React.ReactNode;
  label: string;
  count: number;
  isSelected: boolean;
  handleClearFilter: () => void;
}

export const SegmentedView = ({
  icon,
  label,
  count,
  isSelected,
  handleClearFilter,
}: SegmentedViewProps) => {
  return (
    <div className="flex py-1 bg-gray-100  items-center justify-between mx-auto rounded-[4px] px-6">
      <div className="flex items-center space-x-3 h-[30px]">
        <div className="flex-shrink-0">{icon}</div>
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
