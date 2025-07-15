import React, { useRef, useState, ReactNode, useEffect } from 'react';

import { twMerge } from 'tailwind-merge';

interface TabsProps extends React.HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
  variant?: 'enclosed' | 'subtle';
}

export const Tabs = ({ children, variant = 'enclosed', ...props }: TabsProps) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [highlightStyle, setHighlightStyle] = useState({
    width: 0,
    height: 0,
    left: 0,
  });

  useEffect(() => {
    const container = containerRef.current;

    if (!container) return;

    const activeBtn = container.querySelector('[data-state="active"]') as HTMLElement | null;

    if (!activeBtn) return;

    const containerRect = container.getBoundingClientRect();
    const btnRect = activeBtn.getBoundingClientRect();

    setHighlightStyle({
      width: btnRect.width,
      height: btnRect.height,
      left: btnRect.left - containerRect.left,
    });
  }, [children]);

  return (
    <div
      {...props}
      ref={containerRef}
      className={twMerge(
        'flex items-center gap-2 relative w-fit', //
        variant === 'enclosed' && 'bg-gray-100 p-[2px] rounded-full',
        props.className
      )}
    >
      {variant === 'enclosed' && (
        <span
          className="absolute top-[2px] left-0 bg-gray-25 rounded-full transition-all duration-300 pointer-events-none"
          style={{
            width: highlightStyle.width,
            height: highlightStyle.height,
            transform: `translateX(${highlightStyle.left}px)`,
          }}
        />
      )}

      {React.Children.map(children, child => {
        if (!React.isValidElement(child)) return null;

        const typedChild = child as React.ReactElement<Record<string, unknown>>;
        const isActive = typedChild.props['data-state'] === 'active';

        return React.cloneElement(typedChild, {
          className: twMerge(
            'text-sm font-medium transition z-10',
            typedChild.props.className as string | undefined,
            variant === 'enclosed' && [
              isActive
                ? 'bg-white text-primary-700 hover:text-primary-700 rounded-full border-transparent !shadow-[0]'
                : 'text-gray-600 !hover:bg-gray-50 rounded-full border-transparent !shadow-[0] focus-visible:border-primary-500 focus-visible:border-1 focus-visible:bg-gray-100',
            ],
            variant === 'subtle' && [
              isActive
                ? 'text-gray-800 border-gray-700 border-[1px] border-transparent !bg-gray-100 hover:bg-gray-100 !shadow-[0] focus-visible:border-gray-700 focus-visible:border-1'
                : 'text-gray-600 hover:bg-gray-100 border-transparent focus-visible:border-gray-700 focus-visible:border-1 focus:bg-white bg-transparent !shadow-[0]',
            ]
          ),
        });
      })}
    </div>
  );
};
