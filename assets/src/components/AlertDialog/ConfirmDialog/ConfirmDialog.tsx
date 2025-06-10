import React, { useRef, MouseEventHandler } from 'react';

import { Button, ButtonProps } from 'src/components/Button';

import {
  AlertDialog,
  AlertDialogBody,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogPortal,
  AlertDialogContent,
  AlertDialogOverlay,
  AlertDialogCloseButton,
  AlertDialogConfirmButton,
  AlertDialogCloseIconButton,
} from '../AlertDialog';

interface ConfirmDeleteDialogProps {
  title: string;
  isOpen: boolean;
  isLoading?: boolean;
  onClose: () => void;
  description?: string;
  body?: React.ReactNode;
  hideCloseButton?: boolean;
  confirmButtonLabel: string;
  cancelButtonLabel?: string;
  loadingButtonLabel?: string;
  colorScheme?: ButtonProps['colorScheme'];
  onConfirm: MouseEventHandler<HTMLButtonElement>;
}

export const ConfirmDialog = ({
  isOpen,
  onClose,
  isLoading,
  onConfirm,
  title,
  description,
  body,
  confirmButtonLabel,
  cancelButtonLabel = 'Cancel',
  loadingButtonLabel = 'Loading action...',
  colorScheme = 'primary',
  hideCloseButton,
}: ConfirmDeleteDialogProps) => {
  const cancelRef = useRef<HTMLButtonElement>(null);

  return (
    <AlertDialog isOpen={isOpen} onClose={onClose} className="z-[99999]">
      <AlertDialogPortal>
        <AlertDialogOverlay>
          <AlertDialogContent className="rounded-xl ">
            <div className="flex items-start justify-between w-full">
              <p className="font-semibold line-clamp-2">{title}</p>
              {!hideCloseButton && <AlertDialogCloseIconButton className="mt-[3px]" />}
            </div>

            <AlertDialogHeader className="font-bold">
              {description && (
                <p className="mt-1 text-sm text-grayModern-700 font-normal">{description}</p>
              )}
            </AlertDialogHeader>
            {body && <AlertDialogBody>{body}</AlertDialogBody>}
            <AlertDialogFooter>
              <AlertDialogCloseButton>
                <Button
                  size="sm"
                  ref={cancelRef}
                  variant="outline"
                  colorScheme="gray"
                  isDisabled={isLoading}
                  className="bg-white w-full"
                >
                  {cancelButtonLabel}
                </Button>
              </AlertDialogCloseButton>
              <AlertDialogConfirmButton asChild>
                <Button
                  size="sm"
                  variant="outline"
                  className="w-full"
                  onClick={onConfirm}
                  isLoading={isLoading}
                  loadingText={loadingButtonLabel}
                  colorScheme={colorScheme || 'primary'}
                >
                  {confirmButtonLabel}
                </Button>
              </AlertDialogConfirmButton>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialogOverlay>
      </AlertDialogPortal>
    </AlertDialog>
  );
};
