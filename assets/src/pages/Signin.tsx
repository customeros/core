import { useState } from 'react';
import { useForm, usePage, router } from '@inertiajs/react';

import { RootLayout } from '../layouts/Root';
import { Input } from '../components/Input';
import { Button } from '../components/Button';
import { cn } from 'src/utils/cn';

export const Signin = () => {
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

  // if (showPersonalEmailError) {
  //   return (
  //     <RootLayout>
  //       <div className="h-screen w-screen flex overflow-hidden max-h-screen max-w-screen">
  //         <div className="flex-1 items-center h-screen overflow-hidden">
  //           <div className="h-full flex items-center justify-center relative">
  //             <div className="relative flex flex-col items-center justify-center w-[768px] h-full px-6 pb-6 bg-white">
  //               <div className="h-full flex items-center justify-center relative">
  //                 <div className="flex flex-col items-center justify-center w-full">
  //                   <div className="flex flex-col items-center w-[360px] z-10">
  //                     <img width={264} alt="CustomerOS" src="/images/CustomerOs-logo.png" />
  //                   </div>
  //                   <div className="space-y-2 text-center pt-4 -mt-[60px]  w-[360px]">
  //                     <p className="font-semibold text-3xl">Sign in with your work email</p>
  //                     <p className="text-gray-500">
  //                       Looks like you&apos;re trying to sign in with a personal email like Gmail or
  //                       Yahoo.
  //                     </p>
  //                     <p className="text-gray-500">
  //                       To sign in, you&apos;ll need to use your work or company email instead.
  //                     </p>
  //                     <Button
  //                       variant="outline"
  //                       className="mt-4 w-full"
  //                       onClick={() => {
  //                         setEmailSent(false);
  //                         reset();
  //                       }}
  //                     >
  //                       Go back
  //                     </Button>
  //                   </div>
  //                 </div>
  //               </div>
  //             </div>
  //           </div>
  //         </div>
  //       </div>
  //     </RootLayout>
  //   );
  // }

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
                          Welcome back
                        </p>
                      </>
                    )}
                  </div>
                  <form onSubmit={submit} className="flex flex-col items-center gap-4 w-[360px]">
                    {emailSent ? (
                      <div className="space-y-2 text-center pt-4 -mt-[60px]">
                        <p className="font-semibold text-3xl">Check your email</p>
                        <p className="text-gray-500">
                          We've sent you an email with a magic code to {data.email}
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
                        <p className="text-base mt-3">Sign in to your account</p>
                        <div className="w-full flex flex-col items-start">
                          <Input
                            placeholder="Enter your email"
                            variant="outline"
                            value={data.email}
                            className="rounded-lg"
                            onChange={e => setData('email', e.target.value)}
                            invalid={!!errors.email}
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
                          className="w-full"
                          colorScheme="primary"
                          isDisabled={processing}
                          type="submit"
                        >
                          Sign in
                        </Button>
                        <p className="text-gray-500">We'll send you an email with a magic link</p>
                      </>
                    )}

                    {!emailSent && (
                      <>
                        <div className="w-full h-1 border-t" />
                        <div className="text-gray-500 text-center text-xs">
                          By logging in you agree to CustomerOS's
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
};
