import { useState, lazy, useCallback, useMemo } from 'react';
import { router } from '@inertiajs/react';

import { cn } from 'src/utils/cn';
import { RootLayout } from 'src/layouts/Root';
import { Lead, Tenant, User } from 'src/types';
import { Tooltip } from 'src/components/Tooltip';
import { Icon, IconName } from 'src/components/Icon';
import { SegmentedView } from 'src/components/SegmentedView';
import { LeadUpdatedEvent, useEventsChannel } from 'src/hooks';
import {
  ScrollAreaRoot,
  ScrollAreaThumb,
  ScrollAreaViewport,
  ScrollAreaScrollbar,
} from 'src/components/ScrollArea';

import { Header, EmptyState } from './components';
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

export default function Leads({ companies }: LeadsProps) {
  const [selectedStage, setSelectedStage] = useState<string>('');
  const [scrollProgress, setScrollProgress] = useState(0);
  const hasLeadParam = new URLSearchParams(window.location.search).has('lead');
  const viewMode = new URLSearchParams(window.location.search).get('viewMode');
  const params = new URLSearchParams(window.location.search);
  const currentLeadId = params.get('lead');

  const filteredCompanies = useMemo(
    () => (selectedStage ? companies.filter(c => c.stage === selectedStage) : companies),
    [selectedStage, companies]
  );

  const isSelected = (stage: string) => {
    return !!selectedStage && selectedStage === stage;
  };

  const handleOpenLead = useCallback((lead: { id: string }) => {
    if (currentLeadId === lead.id || params.size === 1) {
      params.delete('lead');
    }
    if (params.size === 0) {
      params.set('lead', lead.id ?? '');
    }

    router.visit(window.location.pathname + '?' + params.toString(), {
      preserveState: true,
      replace: true,
      preserveScroll: true,
    });
  }, []);

  return (
    <RootLayout>
      <EventSubscriber />
      <Header />
      {companies.length === 0 ? (
        <EmptyState />
      ) : (
        <div className="relative h-[calc(100vh-3rem)] overflow-x-hidden bg-white p-0 transition-[width] duration-300 ease-in-out w-full 2xl:w-[1440px] 2xl:mx-auto animate-fadeIn">
          <div className="w-full flex">
            <div className="flex-1 flex flex-col overflow-hidden">
              <div className="w-full items-center justify-center mb-2 mt-2 p-1 hidden md:flex max-w-[800px] mx-auto bg-primary-25 rounded-[8px] transition-all duration-200">
                {stages.map((stage, index) => {
                  const count = companies.filter(c => c.stage === stage.value).length;
                  const prevCount = companies.filter(
                    c => c.stage === stages[index - 1]?.value
                  ).length;
                  const nextCount = companies.filter(
                    c => c.stage === stages[index + 1]?.value
                  ).length;

                  return (
                    <div
                      key={stage.value}
                      className={cn(
                        'flex-1 flex items-center justify-center bg-primary-100 cursor-pointer hover:bg-primary-200 duration-300',
                        scrollProgress < 0.2 && count > nextCount && 'rounded-r-md',
                        scrollProgress < 0.2 && count > prevCount && 'rounded-l-md',
                        scrollProgress > 0.2 && index === 0 && 'rounded-l-md',
                        scrollProgress > 0.2 && index === stages.length - 1 && 'rounded-r-md',
                        selectedStage === stage.value && 'bg-primary-200',
                        count === 0 && 'cursor-not-allowed hover:bg-primary-100'
                      )}
                      style={{
                        height:
                          scrollProgress < 0.2
                            ? `${count ? Math.min((count / Math.max(...stages.map(s => companies.filter(c => c.stage === s.value).length))) * 100, 100) : 15}px`
                            : '20px',
                        zIndex: 10 - index,
                        maxHeight: '100px',
                        minHeight: '20px',
                      }}
                      onClick={e => {
                        e.stopPropagation();
                        count > 0 &&
                          setSelectedStage(prev => (prev === stage.value ? '' : stage.value));
                      }}
                    >
                      <div className="flex text-center text-primary-700 select-none">
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
              <ScrollAreaRoot>
                <ScrollAreaViewport
                  className="absolute"
                  onScroll={e => {
                    if (e.target instanceof HTMLElement) {
                      const scrollTop = e.target.scrollTop;
                      const maxScroll = 200;
                      const progress = Math.min(scrollTop / maxScroll, 1);
                      setScrollProgress(progress);
                    }
                  }}
                >
                  <div className="">
                    {stages
                      .filter(stage => !selectedStage || stage.value === selectedStage)
                      .map((stage, index) => (
                        <div key={stage.value} className="flex flex-col w-full">
                          <SegmentedView
                            label={stage.label}
                            className={cn(
                              'sticky top-0 z-30',
                              index === 0 ? 'mt-0' : '',
                              params.size !== 0 && 'md:rounded-r-none'
                            )}
                            isSelected={isSelected(stage.value)}
                            count={companies.filter(c => c.stage === stage.value).length}
                            icon={<Icon name={stage.icon as IconName} className="text-gray-500" />}
                            handleClearFilter={() => {
                              setSelectedStage('');
                            }}
                            onClick={() => {
                              setSelectedStage(stage.value);
                            }}
                          />

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
                                        handleOpenLead(c);
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
                                      {c?.icp_fit === 'strong' && (
                                        <Icon
                                          name="flame"
                                          className="absolute bottom-[5px] left-[35px] w-[14px] h-[14px] z-20 text-error-500 ring-offset-1
                                        rounded-full  ring-[1px] bg-error-100 ring-white"
                                        />
                                      )}
                                    </div>
                                  )}
                                  <p
                                    className="py-2 px-2 cursor-pointer font-medium truncate"
                                    onClick={() => {
                                      handleOpenLead(c);
                                    }}
                                  >
                                    {c.name || 'Unnamed'}
                                  </p>
                                </div>
                                <p className="flex-4 text-right mr-4 min-w-0 flex-shrink-0 bg-white hidden md:block group-hover:bg-gray-50">
                                  <span className="bg-gray-100 w-fit px-2 py-1 rounded-[4px] max-w-[100px] truncate">
                                    {c.industry}
                                  </span>
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
                        </div>
                      ))}
                  </div>
                </ScrollAreaViewport>
                <ScrollAreaScrollbar orientation="horizontal" className="z-40">
                  <ScrollAreaThumb />
                </ScrollAreaScrollbar>
                <ScrollAreaScrollbar orientation="vertical" className="z-40">
                  <ScrollAreaThumb />
                </ScrollAreaScrollbar>
              </ScrollAreaRoot>
            </div>
            <div
              className={cn(
                'border-l h-full flex-shrink-0 transition-all duration-300 ease-in-out overflow-y-auto',
                hasLeadParam
                  ? 'opacity-100 w-[100%] md:w-[728px] translate-x-[0px]'
                  : 'opacity-0 w-[0px] translate-x-[728px]',
                viewMode === 'focus' && 'w-full border-transparent'
              )}
            >
              <DocumentEditor selectedLead={currentLeadId} />
            </div>
          </div>
        </div>
      )}
    </RootLayout>
  );
}

const EventSubscriber = () => {
  useEventsChannel<LeadUpdatedEvent>(event => {
    if (event.type === 'lead_updated') {
      router.reload({ only: ['companies'] });
    }
  });

  return null;
};
