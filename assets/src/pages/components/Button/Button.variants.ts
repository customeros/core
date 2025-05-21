import { cva } from 'class-variance-authority';
export const iconVariant = cva('', {
  variants: {
    size: {
      xxs: [],
      xs: [],
      sm: [],
      md: [],
      lg: [],
    },
    variant: {
      solid: [],
      outline: [],
      link: [],
      ghost: [],
    },
    colorScheme: {
      primary: [],
      gray: [],
    },
  },
  compoundVariants: [
    {
      size: 'xxs',
      variant: 'solid',
      colorScheme: 'primary',
      className: ['w-3 h-3', 'text-white'],
    },
    {
      size: 'xxs',
      variant: 'solid',
      colorScheme: 'gray',
      className: ['w-3 h-3', 'text-white'],
    },
    {
      size: 'xxs',
      variant: 'outline',
      colorScheme: 'primary',
      className: ['w-3 h-3', 'text-primary-600'],
    },
    {
      size: 'xxs',
      variant: 'outline',
      colorScheme: 'gray',
      className: ['w-3 h-3', 'text-gray-600'],
    },
    {
      size: 'xxs',
      variant: 'link',
      colorScheme: 'primary',
      className: ['w-3 h-3', 'text-primary-700'],
    },
    {
      size: 'xxs',
      variant: 'link',
      colorScheme: 'gray',
      className: ['w-3 h-3', 'text-gray-700'],
    },
    {
      size: 'xxs',
      variant: 'ghost',
      colorScheme: 'primary',
      className: ['w-3 h-3', 'text-primary-700'],
    },
    {
      size: 'xxs',
      variant: 'ghost',
      colorScheme: 'gray',
      className: ['w-3 h-3', 'text-gray-700'],
    },
    {
      size: 'xs',
      variant: 'solid',
      colorScheme: 'primary',
      className: ['w-4 h-4', 'text-white'],
    },
    {
      size: 'xs',
      variant: 'solid',
      colorScheme: 'gray',
      className: ['w-4 h-4', 'text-white'],
    },
    {
      size: 'xs',
      variant: 'outline',
      colorScheme: 'primary',
      className: ['w-4 h-4', 'text-primary-600'],
    },
    {
      size: 'xs',
      variant: 'outline',
      colorScheme: 'gray',
      className: ['w-4 h-4', 'text-gray-600'],
    },
    {
      size: 'xs',
      variant: 'link',
      colorScheme: 'primary',
      className: ['w-4 h-4', 'text-primary-700'],
    },
    {
      size: 'xs',
      variant: 'link',
      colorScheme: 'gray',
      className: ['w-4 h-4', 'text-gray-700'],
    },
    {
      size: 'xs',
      variant: 'ghost',
      colorScheme: 'primary',
      className: ['w-4 h-4', 'text-primary-700'],
    },
    {
      size: 'xs',
      variant: 'ghost',
      colorScheme: 'gray',
      className: ['w-4 h-4', 'text-gray-700'],
    },
    {
      size: 'sm',
      variant: 'solid',
      colorScheme: 'primary',
      className: ['w-5 h-5', 'text-white'],
    },
    {
      size: 'sm',
      variant: 'solid',
      colorScheme: 'gray',
      className: ['w-5 h-5', 'text-white'],
    },
    {
      size: 'sm',
      variant: 'outline',
      colorScheme: 'primary',
      className: ['w-5 h-5', 'text-primary-600'],
    },
    {
      size: 'sm',
      variant: 'outline',
      colorScheme: 'gray',
      className: ['w-5 h-5', 'text-gray-600'],
    },
    {
      size: 'sm',
      variant: 'link',
      colorScheme: 'primary',
      className: ['w-5 h-5', 'text-primary-700'],
    },
    {
      size: 'sm',
      variant: 'link',
      colorScheme: 'gray',
      className: ['w-5 h-5', 'text-gray-700'],
    },
    {
      size: 'sm',
      variant: 'ghost',
      colorScheme: 'primary',
      className: ['w-5 h-5', 'text-primary-700'],
    },
    {
      size: 'sm',
      variant: 'ghost',
      colorScheme: 'gray',
      className: ['w-5 h-5', 'text-gray-700'],
    },
    {
      size: 'md',
      variant: 'solid',
      colorScheme: 'primary',
      className: ['w-5 h-5', 'text-white'],
    },
    {
      size: 'md',
      variant: 'solid',
      colorScheme: 'gray',
      className: ['w-5 h-5', 'text-white'],
    },
    {
      size: 'md',
      variant: 'outline',
      colorScheme: 'primary',
      className: ['w-5 h-5', 'text-primary-600'],
    },
    {
      size: 'md',
      variant: 'outline',
      colorScheme: 'gray',
      className: ['w-5 h-5', 'text-gray-600'],
    },
    {
      size: 'md',
      variant: 'link',
      colorScheme: 'primary',
      className: ['w-5 h-5', 'text-primary-700'],
    },
    {
      size: 'md',
      variant: 'link',
      colorScheme: 'gray',
      className: ['w-5 h-5', 'text-gray-700'],
    },
    {
      size: 'md',
      variant: 'ghost',
      colorScheme: 'primary',
      className: ['w-5 h-5', 'text-primary-700'],
    },
    {
      size: 'md',
      variant: 'ghost',
      colorScheme: 'gray',
      className: ['w-5 h-5', 'text-gray-700'],
    },
    {
      size: 'lg',
      variant: 'solid',
      colorScheme: 'primary',
      className: ['w-6 h-6', 'text-white'],
    },
    {
      size: 'lg',
      variant: 'solid',
      colorScheme: 'gray',
      className: ['w-6 h-6', 'text-white'],
    },
    {
      size: 'lg',
      variant: 'outline',
      colorScheme: 'primary',
      className: ['w-6 h-6', 'text-primary-600'],
    },
    {
      size: 'lg',
      variant: 'outline',
      colorScheme: 'gray',
      className: ['w-6 h-6', 'text-gray-600'],
    },
    {
      size: 'lg',
      variant: 'link',
      colorScheme: 'primary',
      className: ['w-6 h-6', 'text-primary-700'],
    },
    {
      size: 'lg',
      variant: 'link',
      colorScheme: 'gray',
      className: ['w-6 h-6', 'text-gray-700'],
    },
    {
      size: 'lg',
      variant: 'ghost',
      colorScheme: 'primary',
      className: ['w-6 h-6', 'text-primary-700'],
    },
    {
      size: 'lg',
      variant: 'ghost',
      colorScheme: 'gray',
      className: ['w-6 h-6', 'text-gray-700'],
    },
  ],
});

export const linkButton = cva(
  [
    'inline-flex',
    'items-center',
    'justify-center',
    'whitespace-nowrap',
    'gap-2',
    'text-base',
    'font-medium',
    'shadow-xs',
    'outline-none',
    'transition',
    'disabled:cursor-not-allowed',
    'disabled:opacity-50',
  ],
  {
    variants: {
      colorScheme: {
        primary: [
          'text-primary-700',
          'hover:text-primary-700',
          'focus:text-primary-700',
          'hover:underline',
          'focus:underline',
        ],
        gray: [
          'text-gray-500',
          'hover:text-gray-700',
          'focus:text-gray-700',
          'hover:underline',
          'focus:underline',
        ],
      },
    },
    defaultVariants: {
      colorScheme: 'gray',
    },
  }
);

export const solidButton = cva(
  [
    'inline-flex',
    'items-center',
    'justify-center',
    'whitespace-nowrap',
    'gap-2',
    'text-base',
    'font-medium',
    'shadow-xs',
    'outline-none',
    'transition',
    'disabled:cursor-not-allowed',
    'disabled:opacity-50',
  ],
  {
    variants: {
      colorScheme: {
        primary: [
          'text-white',
          'border',
          'border-solid',
          'bg-primary-600',
          'hover:bg-primary-700',
          'focus:bg-primary-700',
          'border-primary-600',
          'hover:border-primary-700',
          'focus:shadow-ringPrimary',
          'focus-visible:shadow-ringPrimary',
        ],
        gray: [
          'text-white',
          'border',
          'border-solid',
          'bg-gray-600',
          'hover:bg-gray-700',
          'focus:bg-gray-700',
          'border-gray-600',
          'hover:border-gray-700',
          'focus:shadow-ringPrimary',
          'focus-visible:shadow-ringPrimary',
        ],
      },
    },
    defaultVariants: {
      colorScheme: 'gray',
    },
  }
);

export const ghostButton = cva(
  [
    'inline-flex',
    'items-center',
    'justify-center',
    'whitespace-nowrap',
    'gap-2',
    'text-base',
    'font-medium',
    'shadow-xs',
    'outline-none',
    'transition',
    'disabled:cursor-not-allowed',
    'disabled:opacity-50',
  ],
  {
    variants: {
      colorScheme: {
        primary: [
          'bg-transparent',
          'text-primary-700',
          'shadow-none',
          'border',
          'border-solid',
          'border-transparent',
          'hover:text-primary-700',
          'focus:text-primary-700',
          'hover:bg-primary-100',
          'focus:bg-primary-100',
        ],
        gray: [
          'bg-transparent',
          'shadow-none',
          'border',
          'border-solid',
          'border-transparent',
          'text-gray-700',
          'hover:text-gray-700',
          'focus:text-gray-700',
          'hover:bg-gray-100',
          'focus:bg-gray-100',
        ],
      },
    },
    defaultVariants: {
      colorScheme: 'gray',
    },
  }
);

export const outlineButton = cva(
  [
    'inline-flex',
    'items-center',
    'justify-center',
    'whitespace-nowrap',
    'gap-2',
    'text-base',
    'font-medium',
    'shadow-xs',
    'outline-none',
    'transition',
    'disabled:cursor-not-allowed',
    'disabled:opacity-50',
  ],
  {
    variants: {
      colorScheme: {
        primary: [
          'bg-primary-50',
          'text-primary-700',
          'border',
          'border-solid',
          'border-primary-300',
          'hover:bg-primary-100',
          'hover:text-primary-700',
          'focus:bg-primary-100',
        ],
        gray: [
          'text-gray-700',
          'border',
          'border-solid',
          'border-gray-300',
          'hover:bg-gray-50',
          'hover:text-gray-700',
          'focus:bg-gray-50',
        ],
      },
    },
    defaultVariants: {
      colorScheme: 'gray',
    },
  }
);
