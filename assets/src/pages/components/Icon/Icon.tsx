import { SVGAttributes } from 'react';

import { twMerge } from 'tailwind-merge';

interface IconProps extends SVGAttributes<SVGElement> {
  name: IconName;
  className?: string;
}

export type IconName =
  | 'rocket-02'
  | 'download-02'
  | 'book-closed'
  | 'lightbulb-02'
  | 'clipboard-check';

export const Icon = ({
  name,
  fill,
  width,
  height,
  stroke,
  className,
  strokeWidth,
  ...props
}: IconProps) => (
  <svg
    viewBox="0 0 24 24"
    width={width ?? 24}
    fill={fill ?? 'none'}
    height={height ?? 24}
    strokeLinecap="round"
    strokeLinejoin="round"
    strokeWidth={strokeWidth ?? 2}
    stroke={stroke ?? 'currentColor'}
    {...props}
    className={twMerge('inline-block size-4', className)}
  >
    <use xlinkHref={`/icons.svg#${name}`} />
  </svg>
);
