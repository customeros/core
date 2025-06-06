import { Button } from 'src/components/Button';

export const EmptyState = () => {
  return (
    <div className="relative w-full flex justify-center flex-col items-center h-[calc(100vh-3rem)]">
      <div className="bg-[url('/images/half-circle-pattern.svg')] bg-cover bg-center bg-no-repeat w-[700px] h-[600px] mt-[-100px] flex items-center justify-center z-[0]">
        <div className="bg-[url('/images/empty-table.svg')] w-[180px] h-[142px] bg-cover bg-center bg-no-repeat translate-y-[135px]" />
      </div>
      <div className="flex flex-col items-center justify-center mt-[-95px]">
        <p className="text-base font-medium text-gray-900 mb-1">Let the leads flow</p>
        <div className="max-w-[340px] text-center gap-2 flex flex-col">
          <p className="">Hang tight, we are now finding 20 highly qualified leads for you....</p>
          <p>
            While you wait, book a call to set up your web tracker and start seeing exactly who’s
            ready to buy.
          </p>
        </div>

        <Button
          colorScheme="primary"
          className="mt-6 w-[226px]"
          onClick={() => {
            window.open('https://cal.com/mbrown/20min', '_blank');
          }}
        >
          Book a call
        </Button>
      </div>
    </div>
  );
};
