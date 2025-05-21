import { Button } from './components/Button/Button';
import { Icon } from './components/Icon/Icon';

export const Leads = () => {
  return (
    <div className="h-full w-full">
      <div className="flex flex-col items-center justify-center">
        <div className=" w-full border-b border-gray-200">
          <div className="flex justify-between items-center w-full py-2 px-4">
            <h1 className="">Leads</h1>
            <div className="flex gap-2">
              <Button colorScheme="primary" size="xs" leftIcon={<Icon name="rocket-02" />}>
                Add Lead
              </Button>
              <Button colorScheme="gray" size="xs" leftIcon={<Icon name="download-02" />}>
                Download
              </Button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
