import { useState } from 'react';
import { useForm } from '@inertiajs/react';

import { cn } from 'src/utils/cn';

import { Input } from '../components/Input';
import { RootLayout } from '../layouts/Root';
import { Button } from '../components/Button';

export default function Signin() {
  const [emailSent, setEmailSent] = useState(false);
  const { data, post, setData, processing, reset, errors } = useForm({
    email: '',
  });

  const submit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    post('/signin', {
      onSuccess: () => {
        setEmailSent(true);
      },
    });
  };

  return (
    <RootLayout>
      <div className="h-screen w-screen flex overflow-hidden max-h-screen max-w-screen">
        <div className="flex-1 items-center h-screen overflow-hidden">
          <div className="h-full flex items-center justify-center relative">
            <div className="relative flex flex-col items-center justify-center w-[768px] h-full px-6 pb-6 bg-white">
              <div className="h-full flex items-center justify-center relative">
                <div className="flex flex-col items-center justify-center w-full">
                  <div className="flex flex-col items-center w-[360px] z-10">
                    <img width={264} alt="CustomerOS" src="/images/CustomerOs-logo.png" />
                    {!emailSent && (
                      <>
                        <p className="text-3xl font-semibold -mt-[34px] text-gray-900">
                          Good to see you
                        </p>
                      </>
                    )}
                  </div>
                  <form onSubmit={submit} className="flex flex-col items-center gap-4 w-[360px]">
                    {emailSent ? (
                      <div className="space-y-2 text-center pt-4 -mt-[60px]">
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
                        <p className="text-base mt-3">We'll email you a magic link to get in </p>
                        <div className="w-full flex flex-col items-start">
                          <Input
                            size="md"
                            type="email"
                            variant="outline"
                            value={data.email}
                            autoComplete="email"
                            invalid={!!errors.email}
                            placeholder="Enter your email"
                            onChange={e => setData('email', e.target.value)}
                          />
                          <p
                            className={cn(
                              'text-error-500 text-xs h-[0px] transition-all mt-0',
                              errors.email?.length && 'h-[13px] mt-1'
                            )}
                          >
                            {errors.email}
                          </p>
                        </div>
                        <Button
                          size="md"
                          type="submit"
                          className="w-full"
                          colorScheme="primary"
                          isDisabled={processing}
                        >
                          Send link
                        </Button>
                      </>
                    )}

                    {!emailSent && (
                      <>
                        <div className="text-gray-500 text-center text-xs pt-4">
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
              </div>
            </div>
          </div>
        </div>
      </div>
    </RootLayout>
  );
}
