import type { Props } from 'react-select';

export type Size = 'xxs' | 'xs' | 'sm' | 'md' | 'lg';
export type MenuWidth = 'fit-item' | 'fit-container';
// Exhaustively typing this Props interface does not offer any benefit at this moment
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export interface SelectProps extends Props<any, any, any> {
  size?: Size;
  isReadOnly?: boolean;
  menuWidth?: MenuWidth;
  leftElement?: React.ReactNode;
  variant?: 'flushed' | 'unstyled' | 'group' | 'outline';
  onKeyDown?: (e: React.KeyboardEvent<HTMLDivElement>) => void;
}
