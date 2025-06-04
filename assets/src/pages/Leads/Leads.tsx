import { useState, lazy, memo, useCallback, useMemo } from 'react';

import { router } from '@inertiajs/react';

import { Icon, IconName } from '../../components/Icon/Icon';
import { SegmentedView } from '../../components/SegmentedView/SegmentedView';
import { Tooltip } from 'src/components/Tooltip';
import { Header, EmptyState } from './components';
import { RootLayout } from 'src/layouts/Root';
import { cn } from 'src/utils/cn';
import {
  CollapsibleRoot,
  CollapsibleContent,
  CollapsibleTrigger,
} from 'src/components/Collapsible';

import { Lead, Tenant, User } from 'src/types';
import { LeadUpdatedEvent, useEventsChannel } from 'src/hooks';

interface LeadsProps {
  companies: Lead[];
  currentUser: User;
  tenant: Tenant;
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
  const [selectedStage, setSelectedStage] = useState<string>('');
  const [selectedAccordion, setSelectedAccordion] = useState<string>('');
  const hasDocParam = new URLSearchParams(window.location.search).has('doc');
  const viewMode = new URLSearchParams(window.location.search).get('viewMode');
  const params = new URLSearchParams(window.location.search);
  const currentDocId = params.get('doc');

  const filteredCompanies = useMemo(
    () => (selectedStage ? companies.filter(c => c.stage === selectedStage) : companies),
    [selectedStage, companies]
  );

  const isSelected = (stage: string) => {
    return !!selectedStage && selectedStage === stage;
  };

  const isAccordionSelected = (stage: string) => {
    return !!selectedAccordion && selectedAccordion === stage;
  };

  const handleOpenDocument = useCallback((company: { document_id: string }) => {
    if (currentDocId === company.document_id || params.size === 1) {
      params.delete('doc');
    }
    if (params.size === 0) {
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
      <Plm />
      <Header />
      {companies.length === 0 ? (
        <EmptyState />
      ) : (
        <div className="flex h-full overflow-hidden relative bg-white p-0 transition-[width] duration-300 ease-in-out w-full 2xl:w-[1440px] 2xl:mx-auto md:mt-2 animate-fadeIn">
          <div className="w-full">
            <div className="w-full items-center justify-center mb-2 p-1 hidden md:flex max-w-[800px] mx-auto bg-primary-25 rounded-[8px]  ">
              {stages.map((stage, index) => {
                const count = companies.filter(c => c.stage === stage.value).length;
                return (
                  <div
                    key={stage.value}
                    className={cn(
                      'flex-1 flex items-center justify-center rounded-md bg-primary-100 cursor-pointer hover:bg-primary-200 duration-300',
                      index > 0 && 'ml-[-10px]',
                      selectedStage === stage.value && 'bg-primary-200',
                      count === 0 && 'cursor-not-allowed hover:bg-primary-100'
                    )}
                    style={{
                      height: `${count ? count * 5 : 15}px`,
                      zIndex: 10 - index,
                      maxHeight: '100px',
                      minHeight: '20px',
                    }}
                    onClick={() => count > 0 && setSelectedStage(stage.value)}
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
              <div className="flex-1 overflow-y-auto text-nowrap">
                {stages
                  .filter(stage => !selectedStage || stage.value === selectedStage)
                  .map((stage, index) => (
                    <CollapsibleRoot
                      key={stage.value}
                      defaultOpen
                      open={selectedAccordion ? isAccordionSelected(stage.value) : true}
                      className="flex flex-col w-full"
                    >
                      <CollapsibleTrigger className="w-full">
                        <SegmentedView
                          label={stage.label}
                          className={cn(
                            index === 0 ? 'mt-0' : '',
                            params.size !== 0 && 'md:rounded-r-none'
                          )}
                          isSelected={isSelected(stage.value) || isAccordionSelected(stage.value)}
                          count={companies.filter(c => c.stage === stage.value).length}
                          icon={<Icon name={stage.icon as IconName} className="text-gray-500" />}
                          handleClearFilter={() => {
                            setSelectedStage('');
                            setSelectedAccordion('');
                          }}
                          onClick={() => {
                            setSelectedAccordion(stage.value);
                          }}
                        />
                      </CollapsibleTrigger>
                      <CollapsibleContent className="bg-white">
                        {filteredCompanies
                          .filter(c => c.stage === stage.value)
                          .map(c => (
                            <div
                              key={c.id}
                              className="flex items-center w-full relative group hover:bg-gray-50"
                            >
                              <div className="flex items-center gap-2 pl-5 min-w-0 flex-1 md:flex-none md:flex-shrink-0 bg-white group-hover:bg-gray-50">
                                {c.icon ? (
                                  <div
                                    className="cursor-pointer"
                                    onClick={() => {
                                      handleOpenDocument(c);
                                    }}
                                  >
                                    <img
                                      key={c.icon}
                                      src={c.icon}
                                      alt={c.name}
                                      className="size-6 object-contain border border-gray-200 rounded flex-shrink-0 relative "
                                      loading="lazy"
                                    />
                                    {c?.icp_fit === 'strong' && (
                                      <Icon
                                        name="flame"
                                        className="absolute bottom-[5px] left-[35px] w-[14px] h-[14px] z-20 text-error-500 ring-offset-1
                                      rounded-full  ring-[1px] bg-error-100 ring-white"
                                      />
                                    )}
                                  </div>
                                ) : (
                                  <div className="size-6 flex items-center justify-center border border-gray-200 rounded flex-shrink-0">
                                    <Icon name="building-06" />
                                  </div>
                                )}
                                <p
                                  className="py-2 px-2 cursor-pointer font-medium truncate"
                                  onClick={() => {
                                    handleOpenDocument(c);
                                  }}
                                >
                                  {c.name || 'Unnamed'}
                                </p>
                              </div>
                              <p className="flex-4 text-right mr-4 min-w-0 flex-shrink-0 bg-white hidden md:block group-hover:bg-gray-50">
                                {c.industry ? (
                                  <span className="bg-gray-100 w-fit px-2 py-1 rounded-[4px] max-w-[100px] truncate">
                                    {c.industry}
                                  </span>
                                ) : (
                                  // <span className=" w-fit px-2 py-1 rounded-[4px] max-w-[100px] truncate border-[1px] border-gray-300">
                                  //   Industry not found
                                  // </span>
                                  <></>
                                )}
                              </p>

                              <p
                                className="text-right cursor-pointer hover:underline min-w-0 flex-1 md:flex-none md:flex-shrink-0 bg-white px-2 py-1 group-hover:bg-gray-50"
                                onClick={() => {
                                  window.open(`https://${c.domain}`, '_blank');
                                }}
                              >
                                {c.domain}
                              </p>
                              <Tooltip label={c.country_name ?? 'Country not found'}>
                                <p className="text-center text-gray-500 flex-shrink-0 bg-white py-2 pl-1 pr-5 group-hover:bg-gray-50">
                                  {countryCodeToEmoji(c.country)}
                                </p>
                              </Tooltip>
                            </div>
                          ))}
                      </CollapsibleContent>
                    </CollapsibleRoot>
                  ))}
              </div>
              <div
                className={cn(
                  'border-l h-[calc(100vh-100px)] flex-shrink-1 transition-all border-t duration-300 ease-in-out',
                  hasDocParam
                    ? 'opacity-100 w-[728px] translate-x-[0px]'
                    : 'opacity-0 w-[0px] translate-x-[728px]',
                  viewMode === 'focus' && 'w-full border-transparent'
                )}
              >
                <DocumentEditor />
              </div>
            </div>
          </div>
        </div>
      )}
    </RootLayout>
  );
});

const Plm = () => {
  useEventsChannel<LeadUpdatedEvent>(event => {
    if (event.type === 'lead_updated') {
      router.reload({ only: ['companies'] });
    }
  });

  return null;
};
