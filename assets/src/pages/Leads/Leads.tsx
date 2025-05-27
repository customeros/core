import { useMemo, useState, lazy } from 'react';

import clsx from 'clsx';
import { router } from '@inertiajs/react';

import { Icon, IconName } from '../../components/Icon/Icon';
import { SegmentedView } from '../../components/SegmentedView/SegmentedView';
import { Tooltip } from 'src/components/Tooltip';
import { Header } from './components/Header';

interface LeadsProps {
  companies: {
    icon: string;
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
  if (!code || code.toLowerCase() === 'xx') {
    return '🌐';
  }
  try {
    return code
      .toUpperCase()
      .replace(/./g, char => String.fromCodePoint(127397 + char.charCodeAt(0)));
  } catch {
    return '🌐';
  }
};
const DocumentEditor = lazy(() =>
  import('./components/DocumentEditor/DocumentEditor').then(module => ({
    default: module.DocumentEditor,
  }))
);
export const Leads = ({ companies }: LeadsProps) => {
  const [selectedStage, setSelectedStage] = useState<string>('');
  const docId = new URLSearchParams(window.location.search).get('doc');
  const viewMode = new URLSearchParams(window.location.search).get('viewMode');

  const filteredCompanies = useMemo(
    () => (selectedStage ? companies.filter(c => c.stage === selectedStage) : companies),
    [selectedStage, companies]
  );

  const handleOpenDocument = (company: { name: string }) => {
    const params = new URLSearchParams(window.location.search);

    if (params.has('doc')) {
      params.delete('doc');
      router.visit(window.location.pathname + '?' + params.toString(), {
        preserveState: true,
        replace: true,
      });
    } else {
      params.set('doc', company.name.toLowerCase().replace(/\s+/g, '-'));
      router.visit(window.location.pathname + '?' + params.toString(), {
        preserveState: true,
        replace: true,
      });
    }
  };

  return (
    <>
      <div className="flex h-full">
        <div className="h-[47px] w-[10%] bg-transparent border-b border-gray-200 [border-image:linear-gradient(to_left,theme(colors.gray.200),transparent)_1]" />
        <div
          className={clsx(
            'flex h-full overflow-hidden relative bg-white p-0 transition-[width] duration-300 ease-in-out',
            'w-[80%]'
          )}
        >
          <div className="w-full">
            <Header />

            <div className="flex w-full items-center justify-center mb-2">
              {stages.map((stage, index) => {
                const count = companies.filter(c => c.stage === stage.value).length;
                return (
                  <div
                    key={stage.value}
                    className={clsx(
                      'flex-1 flex items-center justify-center rounded-md bg-primary-100 cursor-pointer min-h-[12px]',
                      index > 0 && 'ml-[-10px]',
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

            <div className="flex-1 flex">
              <div
                className={clsx(
                  'flex-1 overflow-y-auto text-nowrap duration-300 ease-in-out',
                  viewMode === 'focus' && 'opacity-0'
                )}
              >
                {stages
                  .filter(stage => !selectedStage || stage.value === selectedStage)
                  .map(stage => (
                    <div key={stage.value} className="flex flex-col w-full">
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
                            className="flex items-center w-full h-full"
                          >
                            <div className="flex items-center gap-2 pl-5">
                              {c.icon ? (
                                <img
                                  src={c.icon}
                                  alt={c.name}
                                  className="size-6 object-contain border border-gray-200 rounded"
                                />
                              ) : (
                                <div className="size-6 flex items-center justify-center border border-gray-200 rounded">
                                  <Icon name="building-06" />
                                </div>
                              )}
                              <p
                                className="py-2 px-4 cursor-pointer font-medium"
                                onClick={() => {
                                  handleOpenDocument(c);
                                }}
                              >
                                {c.name}
                              </p>
                            </div>
                            <p className="flex-4 text-right mr-2">
                              <span className="bg-gray-100 w-fit px-2 py-1 rounded-[4px] max-w-[100px] truncate">
                                {c.industry || 'Not found'}
                              </span>
                            </p>
                            <p
                              className="min-w-[200px] text-right cursor-pointer hover:underline"
                              onClick={() => {
                                window.open(`https://${c.domain}`, '_blank');
                              }}
                            >
                              {c.domain}
                            </p>
                            <Tooltip label={c.country_name ?? 'Not found'}>
                              <p className="mr-2 text-center text-gray-500">
                                \{countryCodeToEmoji(c.country)}
                              </p>
                            </Tooltip>
                          </div>
                        ))}
                    </div>
                  ))}
              </div>
              <div
                className={clsx(
                  'border-l h-[calc(100vh-98px)] flex-shrink-1 transition-all border-t duration-300 ease-in-out',
                  viewMode === 'focus' && 'w-full',
                  viewMode === 'focus' && 'border-transparent',
                  docId && 'opacity-100 w-[600px]',
                  !docId && 'opacity-0 w-0'
                )}
              >
                <DocumentEditor />
              </div>
            </div>
          </div>
        </div>

        <div className="h-[47px] w-[10%] bg-transparent border-b border-gray-200 [border-image:linear-gradient(to_right,theme(colors.gray.200),transparent)_1]" />
      </div>
    </>
  );
};
