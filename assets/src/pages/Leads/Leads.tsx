import { router } from '@inertiajs/react';
import { lazy, useState, useEffect, useCallback, startTransition } from 'react';

import { cn } from 'src/utils/cn';
import { useLocalstorageState } from 'rooks';
import { RootLayout } from 'src/layouts/Root';
import { Button } from 'src/components/Button';
import { useUrlState } from 'src/hooks/useUrlState';
import { LeadUpdatedEvent, useEventsChannel } from 'src/hooks';
import { Lead, User, Stage, Tenant, Profile, UrlState, ChannelAttribution } from 'src/types';
import {
  ScrollAreaRoot,
  ScrollAreaThumb,
  ScrollAreaViewport,
  ScrollAreaScrollbar,
} from 'src/components/ScrollArea';

import { Pipeline, LeadItem, EmptyState } from './components';

interface LeadsProps {
  tenant: Tenant;
  profile: Profile;
  max_count: number;
  current_user: User;
  attribution: ChannelAttribution;
  stage_counts: Record<Stage, number>;
  leads: Lead[] | Record<Stage, Lead[]>;
  attributions_list: ChannelAttribution[];
}

const ContextualPanel = lazy(() =>
  import('./components/ContextualPanel/ContextualPanel').then(module => ({
    default: module.ContextualPanel,
  }))
);

export default function Leads({ leads, stage_counts, max_count }: LeadsProps) {
  const [scroll_progress, setScrollProgress] = useState(0);
  const { getUrlState, setUrlState } = useUrlState<UrlState>({ revalidate: ['leads'] });
  const { viewMode, lead } = getUrlState();
  const [seen] = useLocalstorageState<Record<string, boolean>>('seen-leads', {});

  const handleOpenLead = useCallback(
    (lead: { id: string; stage: Stage }, tab: 'account' | 'engagement' | 'contacts') => {
      setUrlState(
        ({ lead: currentLead, ...rest }) => {
          if (lead.id === currentLead) {
            return {
              ...rest,
              viewMode: 'default',
              tab,
            };
          }

          return {
            ...rest,
            lead: lead.id,
            viewMode: 'default',
          };
        },
        {
          revalidate: ['personas', 'attribution', 'attributions_list'],
        }
      );
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
      {max_count === 0 ? (
        <EmptyState />
      ) : (
        <div className="relative h-[calc(100vh-3rem)] overflow-x-hidden bg-white p-0 transition-[width] duration-300 ease-in-out w-full 2xl:w-[1440px] 2xl:mx-auto animate-fadeIn">
          <div className="w-full flex">
            <div className="flex-1 flex flex-col overflow-hidden">
              <Pipeline
                stageCounts={stage_counts}
                onStageClick={handleStageClick}
                scrollProgress={scroll_progress}
                maxCount={Math.max(...Object.values(stage_counts))}
              />
              <ScrollAreaRoot>
                <ScrollAreaViewport
                  className="absolute [&>div]:!block"
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
                  <div className="flex flex-col w-full border-t-1 border-gray-200">
                    {Array.isArray(leads) &&
                      leads.map(lead => (
                        <LeadItem
                          lead={lead}
                          key={lead.id}
                          isSeen={seen[lead.id]}
                          handleStageClick={handleStageClick}
                          handleOpenLead={() => handleOpenLead(lead, 'account')}
                        />
                      ))}
                  </div>
                  {Array.isArray(leads) && leads.length >= 250 && (
                    <div className="flex flex-col items-center justify-center gap-2 p-4 bg-linear-to-b from-gray-50 to-transparent border-t border-gray-200">
                      <div className="text-sm">
                        You’ve unlocked the{' '}
                        <span className="font-semibold bg-linear-270 from-[#6A11CB] to-[#2575FC] bg-clip-text text-transparent">
                          Turbo Scroll Badge
                        </span>
                        ! Need more leads?
                      </div>

                      <Button
                        size="xs"
                        id="test"
                        colorScheme="primary"
                        onClick={() => {
                          window.location.href =
                            "mailto:hello@customeros.ai?subject=I%20Unlocked%20the%20Turbo%20Scroll%20Badge!&body=Hey%20team%2C%0A%0AI've%20just%20scrolled%20to%20the%20ends%20of%20the%20earth%20(or%20at%20least%20your%20leads%20table)%20and%20earned%20the%20Turbo%20Scroll%20Badge.%20Clearly%2C%20I'm%20on%20a%20mission.%0A%0AMore%20leads%2C%20please!%20Fuel%20me%20up.%0A%0AThanks%2C%0A%5BYour%20Name%5D";
                        }}
                      >
                        Email us
                      </Button>
                    </div>
                  )}
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
              <ContextualPanel />
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
      //this was added to not instant reload with same parameters so you can be able to control the url state
      setTimeout(() => {
        router.reload({ only: ['leads'] });
      }, 500);
    }
  });

  return null;
};
