import { forwardRef, KeyboardEvent, InputHTMLAttributes } from 'react';

import { twMerge } from 'tailwind-merge';
import { cva, VariantProps } from 'class-variance-authority';

export const inputVariants = cva(
  [
    'w-full',
    'ease-in-out',
    'delay-50',
    'hover:transition',
    'disabled:cursor-not-allowed',
    '[&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none',
  ],
  {
    variants: {
      size: {
        xxs: ['py-0.5', 'px-1.5', 'text-xs', 'rounded-md'],
        xs: ['px-2', 'py-1', 'leading-none', 'text-sm', 'rounded-md'],
        sm: ['px-3', 'py-2', 'text-sm', 'rounded-lg'],
        md: ['px-4', 'py-2.5', 'text-sm', 'rounded-lg'],
        lg: ['px-[1.125rem]', 'py-2.5', 'text-base', 'rounded-lg'],
      },
      variant: {
        flushed: [
          'text-gray-700',
          'bg-transparent',
          'placeholder-gray-400',
          'border-b',
          'rounded-none',
          'border-transparent',
          'hover:broder-b',
          'hover:border-gray-300',
          'focus:outline-none',
          'focus:border-b',
          'focus:hover:border-primary-500',
          'focus:border-primary-500',
          'data-[invalid=true]:border-error-500',
          'data-[invalid=true]:focus:border-error-500',
          'data-[invalid=true]:focus:hover:border-error-500',
        ],
        group: ['text-gray-700', 'bg-transparent', 'placeholder-gray-400', 'focus:outline-none'],
        unstyled: [
          'text-gray-700',
          'bg-transparent',
          'placeholder-gray-400',
          'focus:outline-none',
          'resize-none',
        ],
        outline: [
          'text-gray-700',
          'bg-white',
          'placeholder-gray-400',
          'border',
          'border-gray-300',
          'focus:outline-none',
          'focus:border-primary-500',
          'invalid:border-error-500',
          'data-[invalid=true]:border-error-500',
        ],
      },
    },
    defaultVariants: {
      size: 'md',
      variant: 'flushed',
    },
  }
);

export interface InputProps
  extends VariantProps<typeof inputVariants>,
    Omit<InputHTMLAttributes<HTMLInputElement>, 'size'> {
  dataTest?: string;
  invalid?: boolean;
  className?: string;
  placeholder?: string;
  allowKeyDownEventPropagation?: boolean;
  onKeyDown?: (e: KeyboardEvent<HTMLInputElement>) => void;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  (
    {
      size,
      variant,
      allowKeyDownEventPropagation,
      className,
      onKeyDown,
      dataTest,
      invalid,
      ...rest
    },
    ref
  ) => {
    return (
      <input
        {...rest}
        ref={ref}
        data-1p-ignore
        data-test={dataTest}
        data-invalid={invalid}
        className={twMerge(inputVariants({ className, size, variant }))}
        onKeyDown={e => {
          if (onKeyDown) {
            onKeyDown(e);

            return;
          }

          e.stopPropagation();
        }}
      />
    );
  }
);
