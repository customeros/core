import { Button } from './components/Button/Button';
import { Icon } from './components/Icon/Icon';
import { SegmentedView } from './components/SegmentedView/SegmentedView';
import { usePage } from '@inertiajs/react';
import clsx from 'clsx';

interface LeadsProps {
  companies: { name: string; count: number; stage: string; domain: string; industry: string }[];
}

const stages = ['Target', 'Education', 'Solution', 'Evaluation', 'Ready to buy'];

export const Leads = ({ companies }: LeadsProps) => {
  const page = usePage();

  console.log(page);

  return (
    <div className="h-full w-full">
      <div className="flex flex-col items-center justify-center">
        <div className=" w-full border-b border-gray-200">
          <div className="flex justify-between items-center w-full py-2 px-4">
            <h1 className="">Leads</h1>
            <div className="flex gap-2">
              {/* <Button colorScheme="primary" size="xs" leftIcon={<Icon name="rocket-02" />}>
                Add Lead
              </Button> */}
              <Button colorScheme="gray" size="xs" leftIcon={<Icon name="download-02" />}>
                Download
              </Button>
            </div>
          </div>
        </div>

        <div className="w-[70%] max-h-[100px] flex items-center justify-center my-3">
          {stages.map((stage, index) => {
            const count = companies.filter(c => c.stage === stage).length;
            return (
              <div
                key={stage}
                className={clsx(
                  'flex-1 flex items-center justify-center rounded-md bg-primary-100 ',
                  index > 0 && 'ml-[-5px]'
                )}
                style={{ height: `${count ? count * 5 : 15}px`, zIndex: 10 - index }}
              >
                <div className="flex text-center text-primary-700">
                  <span>
                    {stage}
                    <span className="mx-1">•</span>
                  </span>
                  <span>{count}</span>
                </div>
              </div>
            );
          })}
        </div>

        {stages.map(stage => (
          <div key={stage} className="w-full">
            <SegmentedView
              icon={<Icon name="rocket-02" className="text-gray-500" />}
              label={stage}
              count={companies.filter(c => c.stage === stage).length}
            />
            {companies
              .filter(c => c.stage === stage)
              .map(c => (
                <div key={c.name} className="flex w-full hover:bg-gray-100">
                  <p className="flex-1 py-2 px-6">{c.name}</p>
                  <p className="flex-1 text-gray-500">{c.domain}</p>
                  <p className="flex-1 text-gray-500">{c.industry}</p>
                </div>
              ))}
          </div>
        ))}
      </div>
    </div>
  );
};
