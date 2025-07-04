import React, { forwardRef, ElementRef } from 'react';
import * as RadixAlertDialog from '@radix-ui/react-alert-dialog';

import { twMerge } from 'tailwind-merge';
import { cva } from 'class-variance-authority';

import { Icon } from '../Icon';
import { IconButton } from '../IconButton/IconButton';

interface AlertDialogGenericProps extends React.HTMLAttributes<HTMLDivElement> {
  asChild?: boolean;
  className?: string;
  children: React.ReactNode;
}

interface AlertDialogProps {
  isOpen: boolean;
  className?: string;
  onClose: () => void;
  children: React.ReactNode;
}

export const AlertDialog = forwardRef<HTMLDivElement, AlertDialogProps>(
  ({ children, isOpen, onClose, ...props }) => {
    return (
      <RadixAlertDialog.Root open={isOpen} onOpenChange={onClose} {...props}>
        {children}
      </RadixAlertDialog.Root>
    );
  }
);

AlertDialog.displayName = 'AlertDialog';

export const AlertDialogPortal = ({ children, ...props }: AlertDialogGenericProps) => {
  return (
    <RadixAlertDialog.Portal
      container={typeof window !== 'undefined' ? document?.body : null}
      {...props}
    >
      {children}
    </RadixAlertDialog.Portal>
  );
};
//TODO:remove z-[5000] from overlay after chakra-ui is removed
export const AlertDialogOverlay = forwardRef<
  ElementRef<typeof RadixAlertDialog.Overlay>,
  AlertDialogGenericProps
>(({ children, className }, ref) => {
  return (
    <RadixAlertDialog.Overlay
      ref={ref}
      className={twMerge(
        'z-[5000] backdrop-brightness-[.55] data-[state=open]:animate-overlayShow fixed inset-0',
        className
      )}
    >
      {children}
    </RadixAlertDialog.Overlay>
  );
});

const alertContentVariant = cva(
  'z-10 fixed left-[50%] w-[90vw] max-w-[450px]  max-h-[80vh] translate-x-[-50%] rounded-xl bg-white p-6 shadow-xl focus:outline-none outline-offset-2 data-[state=open]:will-change-auto',
  {
    variants: {
      placement: {
        center: ['top-[50%]', 'translate-y-[-50%]', 'data-[state=open]:animate-contentShowCenter'],
        top: ['data-[state=open]:animate-contentShowTop', 'top-[4%]'],
      },
    },
    defaultVariants: {
      placement: 'top',
    },
  }
);

export const AlertDialogContent = forwardRef<
  ElementRef<typeof RadixAlertDialog.Content>,
  AlertDialogGenericProps & { placement?: 'center' | 'top' }
>(({ className, children, placement, ...props }, ref) => {
  return (
    <RadixAlertDialog.Content
      ref={ref}
      className={twMerge(alertContentVariant({ placement, className }))}
      {...props}
    >
      {children}
    </RadixAlertDialog.Content>
  );
});

export const AlertDialogHeader = forwardRef<
  ElementRef<typeof RadixAlertDialog.Title>,
  AlertDialogGenericProps
>(({ children, className }, ref) => {
  return (
    <RadixAlertDialog.Title ref={ref} className={twMerge('pr-8', className)}>
      {children}
    </RadixAlertDialog.Title>
  );
});

export const AlertDialogBody = forwardRef<
  ElementRef<typeof RadixAlertDialog.Description>,
  AlertDialogGenericProps
>(({ className, children, asChild }, ref) => {
  return (
    <RadixAlertDialog.Description
      ref={ref}
      asChild={asChild}
      className={twMerge(className, 'start-6 end-6 flex-1 py-2')}
    >
      {children}
    </RadixAlertDialog.Description>
  );
});

export const AlertDialogFooter = ({ children, className }: AlertDialogGenericProps) => {
  return <div className={twMerge('grid grid-cols-2 pt-4 gap-3', className)}>{children}</div>;
};
export const AlertDialogCloseButton = forwardRef<
  ElementRef<typeof RadixAlertDialog.AlertDialogCancel>,
  RadixAlertDialog.AlertDialogCancelProps
>(({ children, ...props }, ref) => {
  return (
    <RadixAlertDialog.Cancel asChild ref={ref} {...props}>
      {children}
    </RadixAlertDialog.Cancel>
  );
});

export const AlertDialogConfirmButton = forwardRef<
  ElementRef<typeof RadixAlertDialog.Action>,
  RadixAlertDialog.AlertDialogActionProps
>(({ children, ...props }, ref) => {
  return (
    <RadixAlertDialog.Action ref={ref} className="w-full outline-none" {...props}>
      {children}
    </RadixAlertDialog.Action>
  );
});

export const AlertDialogCloseIconButton = forwardRef<
  ElementRef<typeof RadixAlertDialog.Cancel>,
  RadixAlertDialog.AlertDialogCancelProps
>(({ className, ...props }, ref) => {
  return (
    <RadixAlertDialog.Cancel
      asChild
      ref={ref}
      className={twMerge('absolute right-6 top-[23px]', className)}
      {...props}
    >
      <IconButton
        size="xs"
        variant="ghost"
        colorScheme="gray"
        aria-label="Close dialog"
        icon={<Icon name="x-close" />}
      />
    </RadixAlertDialog.Cancel>
  );
});
