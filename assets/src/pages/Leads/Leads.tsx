import { useMemo, useState, lazy, memo, useCallback } from 'react';

import clsx from 'clsx';
import { router, usePage } from '@inertiajs/react';

import { Icon, IconName } from '../../components/Icon/Icon';
import { SegmentedView } from '../../components/SegmentedView/SegmentedView';
import { Tooltip } from 'src/components/Tooltip';
import { Header } from './components/Header';
import { RootLayout } from 'src/layouts/Root';

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
    document_id: string;
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

export const Leads = memo(({ companies }: LeadsProps) => {
  const page = usePage();
  const [selectedStage, setSelectedStage] = useState<string>('');
  const hasDocParam = new URLSearchParams(window.location.search).has('doc');
  const docId = new URLSearchParams(window.location.search).get('doc');
  const viewMode = new URLSearchParams(window.location.search).get('viewMode');

  const filteredCompanies = useMemo(
    () => (selectedStage ? companies.filter(c => c.stage === selectedStage) : companies),
    [selectedStage, companies]
  );

  const handleOpenDocument = useCallback((company: { document_id: string }) => {
    const params = new URLSearchParams(window.location.search);
    const currentDocId = params.get('doc');

    if (currentDocId === company.document_id) {
      params.delete('doc');
    } else {
      params.set('doc', company.document_id ?? '');
    }

    router.visit(window.location.pathname + '?' + params.toString(), {
      preserveState: true,
      replace: true,
      preserveScroll: true,
    });
  }, []);

  return (
    <RootLayout>
      <Header />
      <div
        className={clsx(
          'flex h-full overflow-hidden relative bg-white p-0 transition-[width] duration-300 ease-in-out w-full 2xl:w-[1440px] 2xl:mx-auto mt-2'
        )}
      >
        <div className="w-full">
          <div className="flex w-full items-center justify-center mb-2 px-4 2xl:px-0">
            {stages.map((stage, index) => {
              const count = companies.filter(c => c.stage === stage.value).length;
              return (
                <div
                  key={stage.value}
                  className={clsx(
                    'flex-1 flex items-center justify-center rounded-md bg-primary-100 cursor-pointer min-h-[14px]',
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

          <div className="flex-1 flex w-full">
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
                          key={c.document_id || c.name}
                          className="flex items-center w-full h-full"
                        >
                          <div className="flex items-center gap-2 pl-5">
                            {c.icon ? (
                              <img
                                key={c.icon}
                                src={c.icon}
                                alt={c.name}
                                className="size-6 object-contain border border-gray-200 rounded"
                                loading="lazy"
                              />
                            ) : (
                              <div className="size-6 flex items-center justify-center border border-gray-200 rounded">
                                <Icon name="building-06" />
                              </div>
                            )}
                            <p
                              className="py-2 px-2 cursor-pointer font-medium"
                              onClick={() => {
                                handleOpenDocument(c);
                              }}
                            >
                              {c.name}
                            </p>
                          </div>
                          <p className="flex-4 text-right mr-4">
                            {c.industry ? (
                              <span className="bg-gray-100 w-fit px-2 py-1 rounded-[4px] max-w-[100px] truncate">
                                {c.industry}
                              </span>
                            ) : (
                              <span>Not found</span>
                            )}
                          </p>
                          <p
                            className="text-right cursor-pointer hover:underline"
                            onClick={() => {
                              window.open(`https://${c.domain}`, '_blank');
                            }}
                          >
                            {c.domain}
                          </p>
                          <Tooltip label={c.country_name ?? 'Country not found'}>
                            <p className="mr-5 text-center text-gray-500 ml-4">
                              {countryCodeToEmoji(c.country)}
                            </p>
                          </Tooltip>
                        </div>
                      ))}
                  </div>
                ))}
            </div>
            <div
              className={clsx(
                'border-l h-[calc(100vh-100px)] flex-shrink-1 transition-all border-t duration-300 ease-in-out',
                viewMode === 'focus' && 'w-full',
                viewMode === 'focus' && 'border-transparent',
                hasDocParam ? 'opacity-100 w-[600px] pl-6 pr-6' : 'opacity-0 w-0'
              )}
            >
              {hasDocParam && <DocumentEditor />}
            </div>
          </div>
        </div>
      </div>
    </RootLayout>
  );
});
