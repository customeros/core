import { useState } from 'react';
import { useForm } from '@inertiajs/react';

import { cn } from 'src/utils/cn';

import { Input } from '../../components/Input';
import { RootLayout } from '../../layouts/Root';
import { Button } from '../../components/Button';
import { IcpFitStatus } from './components/IcpFitStatus';

export default function Signin() {
  const [emailSent, setEmailSent] = useState(false);
  const { data, post, setData, processing, reset, errors } = useForm({
    email: '',
    lead: '',
  });

  const submit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    post('/signin', {
      onSuccess: () => {
        setEmailSent(true);
      },
    });
  };

  if (errors?.lead === 'Lead still evaluating') {
    return (
      <RootLayout>
        <IcpFitStatus email={data.email} />
      </RootLayout>
    );
  }

  return (
    <RootLayout>
      <div className="h-screen w-screen flex flex-col items-center justify-start overflow-hidden translate-y-[26%]">
        <div className="flex items-center justify-start flex-col max-w-[768px]">
          <img
            width={88}
            height={88}
            alt="CustomerOS"
            src="/images/logo.svg"
            className=" z-10 object-contain"
          />
          <img
            width={180}
            height={20}
            alt="CustomerOS"
            src="/images/watermark.svg"
            className="mt-4 z-10 object-contain"
          />
        </div>

        {!emailSent && (
          <>
            <p className="text-3xl font-semibold text-gray-900 mt-6">Good to see you</p>
          </>
        )}
        <form onSubmit={submit} className="flex flex-col items-center gap-4 w-[360px]">
          {emailSent ? (
            <div className="space-y-2 text-center pt-4 ">
              <p className="font-semibold text-3xl">Check your email</p>
              <p>
                We've sent you an email with a magic link to{' '}
                <span className="font-medium">{data.email}</span>
              </p>
              <Button
                variant="outline"
                className="mt-4 w-full"
                onClick={() => {
                  setEmailSent(false);
                  reset();
                }}
              >
                Back home
              </Button>
            </div>
          ) : (
            <>
              <div className="w-full flex flex-col items-start">
                <Input
                  size="md"
                  type="email"
                  variant="outline"
                  value={data.email}
                  autoComplete="email"
                  className="mt-4 mb-4"
                  invalid={!!errors.email}
                  placeholder="Enter your email"
                  onChange={e => setData('email', e.target.value)}
                />
                <p
                  className={cn(
                    'text-error-500  h-[0px] transition-all mt-0 text-[12px]',
                    errors.email?.length && 'h-[13px] mt-1',
                    errors.lead?.length && 'h-[13px] mt-1'
                  )}
                >
                  {errors?.lead ? errors?.lead : errors?.email}
                </p>
              </div>
              <Button
                size="md"
                type="submit"
                className="w-full"
                colorScheme="primary"
                isDisabled={processing}
              >
                Next
              </Button>
            </>
          )}

          {!emailSent && (
            <>
              <div className="text-gray-500 text-center text-xs pt-2">
                By signing in you agree to CustomerOS's
                <div className="text-gray-500">
                  <a
                    className="text-primary-700 mr-1 underline"
                    href="https://customeros.ai/legal/terms-of-service"
                  >
                    Terms of Service
                  </a>
                  <span className="mr-1">and</span>
                  <a
                    className="text-primary-700 underline"
                    href="https://www.customeros.ai/legal/privacy-policy"
                  >
                    Privacy Policy
                  </a>
                  .
                </div>
              </div>
            </>
          )}
        </form>
      </div>
    </RootLayout>
  );
}
