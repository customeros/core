import { Button } from 'src/components/Button';
import { Icon } from 'src/components/Icon/Icon';

export const Header = () => {
  return (
    <div className="flex w-full">
      <div className="h-[1px] mb-[-0px] bg-gradient-to-l from-gray-200 to-transparent self-end 2xl:w-[calc((100%-1440px)/2)]" />

      <div className="flex justify-between items-center border-b border-gray-200 w-full 2xl:w-[1440px] 2xl:mx-auto py-2 px-4">
        <h1 className="">Leads</h1>
        <div className="flex gap-2">
          <Button
            colorScheme="gray"
            size="xs"
            leftIcon={<Icon name="download-02" />}
            onClick={() => {
              window.location.href = '/leads/download';
            }}
          >
            Download
          </Button>
        </div>
      </div>

      <div className="h-[1px] mb-[-0px] bg-gradient-to-r from-gray-200 to-transparent self-end 2xl:w-[calc((100%-1440px)/2)]" />
    </div>
  );
};
