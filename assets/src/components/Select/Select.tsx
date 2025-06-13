import ReactSelect from 'react-select';
import { useMemo, forwardRef, useCallback } from 'react';
import type { ControlProps, SelectInstance, ClearIndicatorProps } from 'react-select';

import merge from 'lodash/merge';
import { cn } from 'src/utils/cn';

import { Icon } from '../Icon';
import { SelectProps } from './types';
import { getDefaultClassNames } from './style';

export const Select = forwardRef<SelectInstance, SelectProps>(
  (
    {
      isReadOnly,
      leftElement,
      variant = 'outline',
      size = 'md',
      menuWidth = 'fit-container',
      components: _components,
      classNames,
      onKeyDown,
      ...rest
    },
    ref
  ) => {
    const Control = useCallback(
      ({ children, innerRef, innerProps }: ControlProps) => {
        return (
          <div ref={innerRef} className="flex w-full items-center group" {...innerProps}>
            {leftElement}
            {children}
          </div>
        );
      },
      [leftElement, size, rest.isSearchable]
    );

    const ClearIndicator = useCallback(
      ({ innerProps }: ClearIndicatorProps) => {
        const iconSize = {
          xxs: 'size-3',
          xs: 'size-3',
          sm: 'size-3',
          md: 'size-4',
          lg: 'size-5',
        }[size];

        const wrapperSize = {
          xxs: 'size-4',
          xs: 'size-5',
          sm: 'size-7',
          md: 'size-8',
          lg: 'size-8',
        }[size];

        const { className, ...restInnerProps } = innerProps;

        return (
          <div
            className={cn(
              'flex rounded-md items-center justify-center bg-transparent hover:bg-grayModern-100',
              wrapperSize
            )}
            {...restInnerProps}
          >
            <Icon
              name="x-close"
              className={cn('text-transparent group-hover:text-grayModern-700 ', iconSize)}
            />
          </div>
        );
      },
      [size]
    );

    const components = useMemo(
      () => ({
        Control,
        ClearIndicator,
        ..._components,
        DropdownIndicator: () => null,
      }),
      [Control, _components]
    );
    const defaultClassNames = useMemo(
      () => merge(getDefaultClassNames({ size, isReadOnly, variant, menuWidth }), classNames),
      [size, isReadOnly, classNames, variant, menuWidth]
    );

    return (
      <ReactSelect
        unstyled
        ref={ref}
        components={components}
        tabSelectsValue={false}
        onKeyDown={e => {
          if (onKeyDown) {
            onKeyDown(e);
            e.stopPropagation();
          }
        }}
        {...rest}
        classNames={defaultClassNames}
      />
    );
  }
);
