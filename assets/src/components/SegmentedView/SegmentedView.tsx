import React from 'react';

interface SegmentedViewProps {
  icon: React.ReactNode;
  label: string;
  count: number;
}

export const SegmentedView = ({ icon, label, count }: SegmentedViewProps) => {
  return (
    <div className="bg-gray-100 w-full py-2 px-[26px]">
      <div className="flex items-center space-x-3">
        <div className="flex-shrink-0">{icon}</div>
        <h3 className="font-medium">{label}</h3>
        <p className="text-gray-700"> {count}</p>
      </div>
    </div>
  );
};
