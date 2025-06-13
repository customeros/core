import type { MenuPlacement, ClassNamesConfig } from 'react-select';

import { cn } from 'src/utils/cn';
import { match } from 'ts-pattern';
import { twMerge } from 'tailwind-merge';

import type { Size, MenuWidth, SelectProps } from './types';

import { inputVariants } from '../Input';

export const getDefaultClassNames = ({
  size,
  variant,
  isReadOnly,
  menuWidth,
}: Pick<SelectProps, 'size' | 'isReadOnly' | 'variant' | 'menuWidth'>): ClassNamesConfig => ({
  container: ({ isFocused }) =>
    getContainerClassNames(undefined, variant, {
      size,
      isFocused,
      isReadOnly,
    }),
  menu: ({ menuPlacement }) => getMenuClassNames(menuPlacement)('', size),
  menuList: () => getMenuListClassNames('', menuWidth),
  option: ({ isFocused, isSelected }) => getOptionClassNames('', { isFocused, isSelected }),
  placeholder: () => 'text-gray-400',
  multiValue: () => getMultiValueClassNames(''),
  multiValueLabel: () => getMultiValueLabelClassNames('', size),
  multiValueRemove: () => getMultiValueRemoveClassNames('', size),
  groupHeading: () => 'text-gray-400 text-sm px-3 py-1.5 font-normal',
  valueContainer: () => 'gap-1 mr-0.5 inline-grid',
});

export const getMultiValueRemoveClassNames = (className?: string, size?: string) => {
  const sizeClass = match(size)
    .with('xs', () => 'size-5 *:size-5')
    .with('sm', () => 'size-5 *:size-5')
    .with('md', () => 'size-6 *:size-6')
    .with('lg', () => 'size-7 *:size-7')
    .otherwise(() => '');

  return twMerge(
    'cursor-pointer text-gray-400 mr-0 bg-gray-100 rounded-e-md px-0.5 hover:bg-gray-200 hover:text-warning-700 transition ease-in-out',
    sizeClass,
    className
  );
};

export const getMultiValueClassNames = (className?: string) => {
  const defaultStyle = 'border-none mb-0 bg-transparent mr-0 pl-0';

  return twMerge(defaultStyle, className);
};

export const getMenuClassNames =
  (menuPlacement: MenuPlacement) => (className?: string, size?: Size) => {
    const sizes = match(size)
      .with('xs', () => 'text-sm')
      .with('sm', () => 'text-sm')
      .with('md', () => 'text-md')
      .with('lg', () => 'text-lg')
      .otherwise(() => '');

    const defaultStyle = cn(
      menuPlacement === 'top' ? 'mb-2 animate-slideDownFade' : 'mt-2 animate-slideUpFade'
    );

    return twMerge(defaultStyle, sizes, className);
  };

export const getMenuListClassNames = (className?: string, menuWidth?: MenuWidth) => {
  const defaultStyle =
    'p-2 max-h-[300px] border border-gray-200 bg-white outline-none rounded-lg shadow-lg overflow-y-auto overscroll-auto';

  return twMerge(defaultStyle, className, menuWidth === 'fit-item' && 'w-fit');
};

export const getMultiValueLabelClassNames = (className?: string, size?: string) => {
  const sizeClass = match(size)
    .with('xs', () => 'text-sm')
    .with('sm', () => 'text-sm')
    .with('md', () => 'text-md')
    .with('lg', () => 'text-lg')
    .otherwise(() => '');

  const defaultStyle = cn(
    'bg-gray-100 text-gray-700 px-1 mr-0 rounded-s-md hover:bg-gray-200 transition ease-in-out',
    sizeClass
  );

  return twMerge(defaultStyle, className);
};

export const getContainerClassNames = (
  className?: string,
  variant?: 'flushed' | 'unstyled' | 'group' | 'outline',
  props?: {
    size?: Size;
    isFocused?: boolean;
    isReadOnly?: boolean;
  }
) => {
  const defaultStyle = inputVariants({
    variant: variant || 'flushed',
    size: props?.size,
    className: cn(
      'flex items-center cursor-pointer overflow-visible outline-0',
      props?.isReadOnly && 'pointer-events-none'
      // 'focus-within:border-primary-500 focus-within:hover:border-primary-500'
    ),
  });

  return twMerge(defaultStyle, className, variant);
};

export const getOptionClassNames = (
  className: string = '',
  props: { isFocused?: boolean; isSelected?: boolean }
) => {
  const { isFocused, isSelected } = props;

  return cn(
    'my-[2px] px-3 py-1 rounded-md text-gray-700 truncate transition ease-in-out delay-50 hover:bg-gray-100',
    isSelected && 'bg-gray-50 font-medium leading-normal',
    isFocused && 'bg-gray-100',
    className
  );
};
