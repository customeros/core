import { SVGAttributes } from 'react';

import { twMerge } from 'tailwind-merge';

interface IconProps extends SVGAttributes<SVGElement> {
  name: IconName;
  className?: string;
}

export type IconName =
  | 'rocket-02'
  | 'download-02'
  | 'alert-circle'
  | 'x-close'
  | 'target-04'
  | 'book-closed'
  | 'lightbulb-02'
  | 'clipboard-check'
  | 'trash-01'
  | 'link-external-02'
  | 'bold-01'
  | 'italic-01'
  | 'strikethrough-01'
  | 'underline-01'
  | 'underline-strikethrough-01'
  | 'code-01'
  | 'link-01'
  | 'subscript-01'
  | 'list-bulleted'
  | 'list-numbered'
  | 'block-quote'
  | 'arrow-block-down'
  | 'arrow-block-up'
  | 'expand-01'
  | 'collapse-01'
  | 'building-06'
  | 'magnet'
  | 'radar'
  | 'briefcase-02'
  | 'clock-fast-forward'
  | 'flame'
  | 'user-plus-01'
  | 'building-03'
  | 'check-circle'
  | 'search-sm'
  | 'check'
  | 'distribute-spacing-vertical'
  | 'rows-01'
  | 'recording-01'
  | 'arrow-switch-vertical-01'
  | 'arrows-down'
  | 'arrows-up'
  | 'layers-three-01'
  | 'activity-heart'
  | 'globe-05'
  | 'git-timeline'
  | 'mail-02'
  | 'phone'
  | 'linkedin-solid'
  | 'lock-01'
  | 'copy-03'
  | 'user-03'
  | 'corner-down-right'
  | 'thumbs-down'
  | 'thumbs-down'
  | 'chevron-right'
  | 'chevron-left'
  | 'chevron-down'
  | 'activity'
  | 'handle-drag'
  | 'users-check'
  | 'contrast-01'
  | 'thumbs-up'
  | 'calendar-check-01';

export const Icon = ({
  name,
  fill,
  width,
  height,
  stroke,
  className,
  strokeWidth,
  ...props
}: IconProps) => {
  return (
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
};
