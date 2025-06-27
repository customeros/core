import { useState } from 'react';
import { router } from '@inertiajs/react';

import { cn } from 'src/utils/cn';
import { Button } from 'src/components/Button';
import { useEventsChannel, IcpFitEvaluationCompleteEvent } from 'src/hooks';

export const IcpFitStatus = ({ email }: { email: string }) => {
  const [isFit, setIsFit] = useState<boolean | null>(null);

  useEventsChannel<IcpFitEvaluationCompleteEvent>(event => {
    if (event.type === 'icp_fit_evaluation_complete') {
      setIsFit(event.payload.is_fit);
    }
  }, email);

  return (
    <IcpFitStatusSkeleton isFit={isFit}>
      {isFit === null ? (
        <div className="flex flex-col items-center justify-center max-w-[360px] text-[16px] text-center  max-h-[440px] ">
          <p className="font-bold text-3xl mb-3">Checking if you're a fit...</p>
          <p className="text-center mb-3">Not everyone gets value from CustomerOS.</p>
          <p className="text-center">
            We're checking your details to see if we're the right tool for you.
          </p>

          <Button
            size="md"
            variant="outline"
            className="w-full mt-6"
            onClick={() => router.visit('/')}
          >
            Back home
          </Button>
        </div>
      ) : isFit === false ? (
        <div className="flex flex-col items-center justify-center max-w-[470px] text-[16px] text-center  max-h-[440px] ">
          <p className="font-bold text-3xl mb-3">Looks like a mismatch</p>
          <p className="text-center mb-3">
            It looks like we might not be the best fit for you right now. We'd rather be upfront
            than shoehorn you into something that won't deliver.
          </p>
          <p className="text-center">Still curious? Book a call and let's chat about your needs.</p>
          <Button
            size="md"
            variant="outline"
            className="w-full mt-6"
            onClick={() => window.open('https://cal.com/mbrown/20min', '_blank')}
          >
            Book a call
          </Button>
          <Button
            size="md"
            variant="ghost"
            className="w-full mt-3"
            onClick={() => router.visit('/')}
          >
            Back home
          </Button>
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center max-w-[470px] text-[16px] text-center  max-h-[440px]">
          <p className="font-bold text-3xl mb-3">Bingo, you're a fit</p>
          <p className="text-center mb-3">
            To get you going, we've sent you a confirmation email to{' '}
            <span className="font-semibold">{email}</span>
          </p>

          <Button
            size="md"
            variant="ghost"
            className="w-full mt-6"
            onClick={() => router.visit('/')}
          >
            Back home
          </Button>
        </div>
      )}
    </IcpFitStatusSkeleton>
  );
};

export const IcpFitStatusSkeleton = ({
  children,
  isFit,
}: {
  isFit: boolean | null;
  children: React.ReactNode;
}) => {
  return (
    <div className="h-screen w-screen flex flex-col items-center justify-center overflow-hidden">
      <div className="flex-1 h-full flex flex-col items-center justify-center bg-white relative max-w-[768px] mx-auto">
        <div className="flex items-center justify-center flex-col">
          <div className="flex items-center justify-center flex-col">
            <img
              width={768}
              height={768}
              alt="CustomerOS"
              src="/images/full-circle-pattern.svg"
              className={cn(
                'absolute object-contain translate-y-[8px]',
                isFit === null && 'animate-ripple delay-200'
              )}
            />
            <img
              width={88}
              height={88}
              alt="CustomerOS"
              src="/images/logo.svg"
              className={cn(
                'z-10 object-contain',
                isFit === null && 'animate-pulseScale delay-200'
              )}
            />
          </div>

          <img
            width={180}
            height={20}
            alt="CustomerOS"
            src="/images/watermark.svg"
            className="mt-4 z-10 object-contain"
          />
        </div>
        <div className="relative z-10 flex flex-col items-center justify-start px-6 pb-6 w-full max-w-[768px] min-h-[500px] mt-6">
          {children}
        </div>
      </div>
    </div>
  );
};
