import { usePage } from 'node_modules/@inertiajs/react/types';
import { Tooltip } from 'src/components/Tooltip/Tooltip';
import { User } from 'src/types';

import { cn } from 'src/utils/cn';
interface UserHexagonProps {
  id: string;
  name: string;
  color: string;
  isCurrent?: boolean;
}

export const UserHexagon = ({ name, isCurrent, color, id }: UserHexagonProps) => {
  return (
    <Tooltip hasArrow label={name}>
      <div
        className={cn(
          'flex relative size-7 items-center justify-center cursor-default',
          isCurrent && 'cursor-pointer'
        )}
      >
        <p
          className={cn('text-sm z-[2] rounded-full size-7 flex items-center justify-center')}
          style={{
            color: isCurrent ? 'white' : color,
            backgroundColor: isCurrent ? color : 'white',
            border: !isCurrent ? `1px solid ${color}` : 'none',
          }}
        >
          {getInitials(name)}
        </p>
        <div className="absolute size-[7px] ring-[2px] ring-white bg-success-500 rounded-full right-0.5 bottom-[-1px] z-[3]"></div>
      </div>
    </Tooltip>
  );
};

const ClippedImage = ({
  name,
  color,
  url,
  isCurrent,
}: {
  url: string;
  name: string;
  color: string;
  isCurrent: boolean;
}) => {
  return (
    <Tooltip hasArrow label={name}>
      <div
        className={cn(
          'flex size-7 items-center justify-center rounded-full relative cursor-default',
          isCurrent && 'cursor-pointer'
        )}
      >
        <img
          src={url}
          aria-label={name}
          style={{
            borderColor: color,
          }}
          className={`rounded-full size-[28px] border aspect-square object-cover`}
        />

        <div className="absolute size-[7px] ring-[2px] ring-white bg-success-500 rounded-full right-0.5 bottom-[-1px] z-[3]"></div>
      </div>
    </Tooltip>
  );
};

function getInitials(name: string) {
  const temp = name.toUpperCase().split(' ').splice(0, 2);

  return temp
    .map(s => s[0])
    .join('')
    .trim();
}
