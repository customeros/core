import { cva } from 'class-variance-authority';

export const featureIconVariant = cva(
  ['flex', 'justify-center', 'items-center', 'rounded-full', 'overflow-visible'],
  {
    variants: {
      colorScheme: {
        primary: [],
        gray: [],
        success: [],
        error: [],
      },
    },
    compoundVariants: [
      {
        colorScheme: 'primary',
        className: ['bg-primary-100 ring-primary-50 ring-offset-primary-100 text-primary-600'],
      },
      {
        colorScheme: 'gray',
        className: ['bg-gray-100 ring-gray-50 ring-offset-gray-100 text-gray-600'],
      },
      {
        colorScheme: 'success',
        className: ['bg-success-100 ring-success-50 ring-offset-success-100 text-success-600'],
      },
      {
        colorScheme: 'error',
        className: ['bg-error-100 ring-error-50 ring-offset-error-100 text-error-600'],
      },
    ],
  }
);
