import { useForm } from '@inertiajs/react';
import { Button } from './components/Button/Button';
import { Input } from './components/Input';

export const Signin = () => {
  const { data, post, errors, setData, processing } = useForm({
    email: '',
  });

  const submit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    post('/signin');
  };

  console.log(errors);

  return (
    <div className="h-screen w-screen flex overflow-hidden max-h-screen max-w-screen">
      <div className="flex-1 items-center h-screen overflow-hidden">
        <div className="h-full flex items-center justify-center relative">
          <div className="relative flex flex-col items-center justify-center w-[768px] h-full px-6 pb-6 bg-white">
            <div className="absolute top-0 left-0 w-full h-full bg-[url('/images/dotted-bg-pattern.svg')] bg-cover bg-center bg-no-repeat  max-h-[54%]" />
            <div className="h-full flex items-center justify-center relative  ">
              <div className="flex flex-col items-center justify-center w-full ">
                <div className="flex flex-col items-center w-[360px] z-10">
                  <img width={223} height={40} alt="CustomerOS" src="/images/CustomerOs-logo.png" />
                  <p className="text-3xl font-semibold mt-[28px] text-gray-900">Welcome back</p>
                </div>
                <form onSubmit={submit} className="flex flex-col items-center gap-4 w-full">
                  <p className="text-gray-500">Sign in to your account</p>
                  <Input
                    placeholder="Enter your email"
                    variant="outline"
                    value={data.email}
                    onChange={e => setData('email', e.target.value)}
                  />
                  <Button
                    className="w-full"
                    colorScheme="primary"
                    isDisabled={processing}
                    type="submit"
                  >
                    Sign in with email
                  </Button>
                  <p className="text-gray-500">We'll send you an email with a magic link</p>
                  <div className="w-full h-1 border-t" />
                  <div className="text-gray-500 text-center text-xs">
                    By logging in you agree to CustomerOS&apos;s
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
                </form>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
