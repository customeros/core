import { useMemo, useState } from 'react';

import clsx from 'clsx';
import { router } from '@inertiajs/react';

import { Button } from '../../components/Button/Button';
import { Icon, IconName } from '../../components/Icon/Icon';
import { SegmentedView } from '../../components/SegmentedView/SegmentedView';
import { DocumentEditor } from './DocumentEditor';

interface LeadsProps {
  companies: {
    logo: string;
    name: string;
    count: number;
    stage: string;
    country: string;
    country_name: string;
    domain: string;
    industry: string;
  }[];
}

const stages = [
  { label: 'Target', value: 'target', icon: 'target-04' },
  { label: 'Education', value: 'education', icon: 'book-closed' },
  { label: 'Solution', value: 'solution', icon: 'lightbulb-02' },
  { label: 'Evaluation', value: 'evaluation', icon: 'clipboard-check' },
  { label: 'Ready to buy', value: 'ready_to_buy', icon: 'rocket-02' },
];

const countryCodeToEmoji = (code: string) => {
  return code
    .toUpperCase()
    .replace(/./g, char => String.fromCodePoint(127397 + char.charCodeAt(0)));
};

export const Leads = ({ companies }: LeadsProps) => {
  const [selectedStage, setSelectedStage] = useState<string>('');
  const docId = new URLSearchParams(window.location.search).get('doc');
  const viewMode = new URLSearchParams(window.location.search).get('viewMode');

  const filteredCompanies = useMemo(
    () => (selectedStage ? companies.filter(c => c.stage === selectedStage) : companies),
    [selectedStage, companies]
  );

  return (
    <div
      className={clsx(
        'flex h-full overflow-hidden relative bg-white p-0 transition-[width] duration-300 ease-in-out',
        'w-full'
      )}
    >
      <div className="flex-1 flex flex-col overflow-y-auto">
        <div className="w-full border-b border-gray-200">
          <div className="flex justify-between items-center w-full py-2 px-4">
            <h1 className="">Leads</h1>
            <div className="flex gap-2">
              {/* <Button colorScheme="primary" size="xs" leftIcon={<Icon name="rocket-02" />}>
                Add Lead
              </Button> */}
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

        <div className="w-[70%] max-h-[100px] flex items-center justify-center my-3 mx-auto">
          {stages.map((stage, index) => {
            const count = companies.filter(c => c.stage === stage.value).length;
            return (
              <div
                key={stage.value}
                className={clsx(
                  'flex-1 flex items-center justify-center rounded-md bg-primary-100 cursor-pointer',
                  index > 0 && 'ml-[-5px]',
                  selectedStage === stage.value && 'bg-primary-200'
                )}
                style={{
                  height: `${count ? count * 5 : 15}px`,
                  zIndex: 10 - index,
                  maxHeight: '100px',
                }}
                onClick={() => setSelectedStage(stage.value)}
              >
                <div className="flex text-center text-primary-700">
                  <span>
                    {stage.label}
                    <span className="mx-1">•</span>
                  </span>
                  <span>{count}</span>
                </div>
              </div>
            );
          })}
        </div>

        {stages
          .filter(stage => !selectedStage || stage.value === selectedStage)
          .map(stage => (
            <div key={stage.value} className="w-full">
              <div className="mb-2">
                <SegmentedView
                  icon={<Icon name={stage.icon as IconName} className="text-gray-500" />}
                  label={stage.label}
                  count={companies.filter(c => c.stage === stage.value).length}
                  isSelected={selectedStage === stage.value}
                  handleClearFilter={() => setSelectedStage('')}
                />
              </div>
              {filteredCompanies
                .filter(c => c.stage === stage.value)
                .map(c => (
                  <div
                    key={crypto.randomUUID()}
                    className="flex w-full hover:bg-gray-100 items-center"
                  >
                    <div className="flex pl-6 items-center justify-center">
                      <img src={c.logo} alt={c.name} className="w-10 h-10 rounded-full" />
                    </div>
                    <p
                      className="flex-1 py-2 px-6 cursor-pointer hover:text-primary-600"
                      onClick={() => {
                        const params = new URLSearchParams(window.location.search);
                        params.set('doc', c.name.toLowerCase().replace(/\s+/g, '-'));
                        router.visit(window.location.pathname + '?' + params.toString(), {
                          preserveState: true,
                          replace: true,
                        });
                      }}
                    >
                      {c.name}
                    </p>
                    <p className="flex mr-6 text-gray-500">{countryCodeToEmoji(c.country)}</p>
                    <p className="flex-1 text-gray-500">{c.domain}</p>
                    <p className="flex-1 ">
                      <span className="bg-gray-100 w-fit px-2 py-1 rounded-[4px]">
                        {c.industry}
                      </span>
                    </p>
                  </div>
                ))}
            </div>
          ))}
      </div>
      {docId && (
        <div
          className={clsx(
            'border-l border-gray-200 h-screen flex-shrink-0 transition-all duration-300 ease-in-out',
            viewMode === 'focus' ? 'w-full' : 'w-[600px]'
          )}
        >
          <DocumentEditor />
        </div>
      )}
    </div>
  );
};
