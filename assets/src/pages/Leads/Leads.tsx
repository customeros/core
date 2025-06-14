import { router } from '@inertiajs/react';
import { lazy, useState, useEffect, useCallback, startTransition } from 'react';

import { cn } from 'src/utils/cn';
import { RootLayout } from 'src/layouts/Root';
import { useUrlState } from 'src/hooks/useUrlState';
import { Icon, IconName } from 'src/components/Icon';
import { SegmentedView } from 'src/components/SegmentedView';
import { LeadUpdatedEvent, useEventsChannel } from 'src/hooks';
import { Lead, User, Stage, Tenant, UrlState } from 'src/types';
import {
  ScrollAreaRoot,
  ScrollAreaThumb,
  ScrollAreaViewport,
  ScrollAreaScrollbar,
} from 'src/components/ScrollArea';

import { Header, Pipeline, LeadItem, EmptyState, stageIcons, stageOptions } from './components';
interface LeadsProps {
  tenant: Tenant;
  max_count: number;
  current_user: User;
  stage_counts: Record<Stage, number>;
  leads: Lead[] | Record<Stage, Lead[]>;
}

const DocumentEditor = lazy(() =>
  import('./components/DocumentEditor/DocumentEditor').then(module => ({
    default: module.DocumentEditor,
  }))
);

export default function Leads({ leads, stage_counts, max_count }: LeadsProps) {
  const [scroll_progress, setScrollProgress] = useState(0);
  const { getUrlState, setUrlState } = useUrlState<UrlState>({ revalidate: ['leads'] });
  const { viewMode, group, lead, stage: selectedStage } = getUrlState();

  const handleOpenLead = useCallback(
    (lead: { id: string }) => {
      setUrlState(({ lead: currentLead, ...rest }) => {
        if (lead.id === currentLead) {
          return {
            ...rest,
            viewMode: 'default',
          };
        }

        return {
          ...rest,
          lead: lead.id,
          viewMode: 'default',
        };
      });
    },
    [setUrlState]
  );

  const handleStageClick = (stage: Stage | null) => {
    setUrlState(({ stage: currentStage, ...rest }) => {
      if (stage === currentStage || !stage) {
        return {
          ...rest,
        };
      }

      return {
        ...rest,
        stage: stage,
      };
    });
  };

  useEffect(() => {
    if (viewMode === 'focus' && !lead) {
      setUrlState(state => ({
        ...state,
        viewMode: 'default',
      }));
    }
  }, [lead, viewMode, setUrlState]);

  return (
    <RootLayout>
      <EventSubscriber />
      <Header />
      {max_count === 0 ? (
        <EmptyState />
      ) : (
        <div className="relative h-[calc(100vh-3rem)] overflow-x-hidden bg-white p-0 transition-[width] duration-300 ease-in-out w-full 2xl:w-[1440px] 2xl:mx-auto animate-fadeIn">
          <div className="w-full flex">
            <div className="flex-1 flex flex-col overflow-hidden">
              <Pipeline
                leads={leads}
                max_count={max_count}
                stage_counts={stage_counts}
                onStageClick={handleStageClick}
                scroll_progress={scroll_progress}
              />
              <ScrollAreaRoot>
                <ScrollAreaViewport
                  className="absolute"
                  onScroll={e => {
                    startTransition(() => {
                      if (e.target instanceof HTMLElement) {
                        const scrollTop = e.target.scrollTop;
                        const maxScroll = 200;
                        const progress = Math.min(scrollTop / maxScroll, 1);

                        setScrollProgress(progress);
                      }
                    });
                  }}
                >
                  <div className="">
                    {group === 'stage' && !Array.isArray(leads)
                      ? Object.entries(leads).map(([stage, groupedLeads], index) => (
                          <div key={stage} className="flex flex-col w-full">
                            <SegmentedView
                              isSelected={selectedStage === stage}
                              count={stage_counts[stage as Stage] || 0}
                              label={stageOptions.find(s => s.value === stage)?.label || stage}
                              onClick={() => {
                                handleStageClick(stage as Stage);
                              }}
                              handleClearFilter={() => {
                                handleStageClick(stage as Stage);
                              }}
                              className={cn(
                                'sticky top-0 z-30',
                                index === 0 ? 'mt-0' : '',
                                lead && 'md:rounded-r-none'
                              )}
                              icon={
                                <Icon
                                  className="text-gray-500"
                                  name={stageOptions.find(s => s.value === stage)?.icon as IconName}
                                />
                              ))
                            : null}
                        </div>
                      ))
                    ) : Array.isArray(leads) ? (
                      <div className="flex flex-col w-full">
                        <SegmentedView
                          count={max_count || 0}
                          isSelected={!!selectedStage}
                          className={cn('sticky top-0 z-30 mt-o', lead && 'md:rounded-r-none')}
                          handleClearFilter={() => {
                            handleStageClick(selectedStage as Stage);
                          }}
                          label={
                            selectedStage
                              ? stageOptions.find(s => s.value === selectedStage)?.label ||
                                selectedStage
                              : 'All leads'
                          }
                          icon={
                            <Icon
                              className="text-gray-500"
                              name={
                                selectedStage
                                  ? (stageIcons[selectedStage as Stage] as IconName)
                                  : 'layers-three-01'
                              }
                            />
                          }
                        />
                        {leads.map(lead => (
                          <LeadItem
                            lead={lead}
                            key={lead.id}
                            handleOpenLead={handleOpenLead}
                            handleStageClick={handleStageClick}
                          />
                        ))}
                      </div>
                    ) : null}
                  </div>
                </ScrollAreaViewport>
                <ScrollAreaScrollbar className="z-40" orientation="horizontal">
                  <ScrollAreaThumb />
                </ScrollAreaScrollbar>
                <ScrollAreaScrollbar className="z-40" orientation="vertical">
                  <ScrollAreaThumb />
                </ScrollAreaScrollbar>
              </ScrollAreaRoot>
            </div>
            <div
              className={cn(
                'border-l flex-shrink-0 transition-all duration-300 ease-in-out h-[calc(100vh-50px)] overflow-y-auto',
                lead
                  ? 'opacity-100 w-[100%] md:w-[728px] translate-x-[0px]'
                  : 'opacity-0 w-[0px] translate-x-[728px]',
                viewMode === 'focus' && 'w-full md:w-full border-transparent'
              )}
            >
              <DocumentEditor />
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
