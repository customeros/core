import { Button } from 'src/components/Button';
import { Icon } from 'src/components/Icon/Icon';

export const Header = () => {
  return (
    <div className="w-full mx-auto">
      <div className="flex justify-between items-center w-full py-2 px-4 border-b border-gray-200 mb-2">
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
    </div>
  );
};
