import React from 'react';
import * as PopoverPrimitive from '@radix-ui/react-popover';

import { cn } from 'src/utils/cn';

const Popover = PopoverPrimitive.Root;

const PopoverTrigger = PopoverPrimitive.Trigger;

const PopoverAnchor = PopoverPrimitive.Anchor;

const PopoverContent = React.forwardRef<
  React.ElementRef<typeof PopoverPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof PopoverPrimitive.Content>
>(({ className, align = 'center', sideOffset = 4, ...props }, ref) => (
  <PopoverPrimitive.Portal>
    <PopoverPrimitive.Content
      ref={ref}
      align={align}
      sideOffset={sideOffset}
      className={cn(
        'z-50 w-fit flex relative flex-col rounded-lg border bg-white py-2 px-1 shadow-lg outline-none will-change-[transform,opacity] data-[state=open]:data-[side=top]:animate-slideDownFade data-[state=open]:data-[side=right]:animate-slideLeftFade data-[state=open]:data-[side=bottom]:animate-slideUpFade data-[state=open]:data-[side=left]:animate-slideRightFade',
        className
      )}
      {...props}
    />
  </PopoverPrimitive.Portal>
));

PopoverContent.displayName = PopoverPrimitive.Content.displayName;

export { Popover, PopoverTrigger, PopoverContent, PopoverAnchor };
