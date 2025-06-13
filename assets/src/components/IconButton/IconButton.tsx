import React, { forwardRef, cloneElement } from 'react';

import { twMerge } from 'tailwind-merge';
import { cva, type VariantProps } from 'class-variance-authority';

import { iconVariant } from './IconButton.variants';
import { ghostButton, solidButton, outlineButton } from '../Button/Button.variants';

const buttonSize = cva([], {
  variants: {
    size: {
      xxs: ['p-0.5', 'rounded-md', 'text-md'],
      xs: ['p-1.5', 'rounded-md', 'text-sm'],
      sm: ['p-2', 'rounded-lg', 'text-sm'],
      md: ['p-2.5', 'rounded-lg', 'text-sm'],
      lg: ['p-2.5', 'rounded-lg', 'text-base'],
    },
  },
  defaultVariants: {
    size: 'sm',
  },
});

export interface IconButtonProps
  extends React.HTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof solidButton>,
    VariantProps<typeof buttonSize> {
  asChild?: boolean;
  dataTest?: string;
  isLoading?: boolean;
  isDisabled?: boolean;
  'aria-label': string;
  spinner?: React.ReactElement;
  icon: React.ReactElement<HTMLElement>;
  variant?: 'ghost' | 'solid' | 'outline';
}

export const IconButton = forwardRef<HTMLButtonElement, IconButtonProps>(
  (
    {
      children,
      className,
      dataTest,
      colorScheme = 'gray',
      spinner,
      variant = 'outline',
      isLoading = false,
      isDisabled = false,
      icon,
      size = 'sm',
      'aria-label': ariaLabel,
      ...props
    },
    ref
  ) => {
    const buttonVariant = (() => {
      switch (variant) {
        case 'ghost':
          return ghostButton;
        case 'solid':
          return solidButton;
        case 'outline':
          return outlineButton;
        default:
          return outlineButton;
      }
    })();

    return (
      <button
        ref={ref}
        {...props}
        data-test={dataTest}
        aria-label={ariaLabel}
        disabled={isLoading || isDisabled}
        className={twMerge(
          buttonVariant({ colorScheme, className }),
          buttonSize({ className, size }),
          isLoading ? 'opacity-50 cursor-not-allowed' : '',
          'cursor-pointer'
        )}
      >
        {isLoading && spinner && <span className="relative inline-flex">{spinner}</span>}

        {!isLoading && icon && (
          <>
            {cloneElement(icon, {
              className: twMerge(
                iconVariant({
                  size,
                  variant,
                  colorScheme,
                  className: icon.props.className,
                })
              ),
            })}
          </>
        )}
      </button>
    );
  }
);
