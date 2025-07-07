import type { Stage, UrlState } from 'src/types';

import { useState } from 'react';

import { cn } from 'src/utils/cn';
import { Icon } from 'src/components/Icon/Icon';
import { useUrlState, useEventsChannel, LeadCreatedEvent } from 'src/hooks';

import { stageIcons, stageOptionsWithoutCustomer } from '../util';

interface PipelineProps {
  maxCount: number;
  scrollProgress: number;
  stageCounts: Record<Stage, number>;
  onStageClick: (stage: Stage | null) => void;
}

export const Pipeline = ({
  maxCount,
  stageCounts,
  scrollProgress,
  onStageClick,
}: PipelineProps) => {
  const { getUrlState } = useUrlState<UrlState>();
  const { pipeline, stage: selectedStage, group, lead } = getUrlState();
  const [newLead, setNewLead] = useState<Record<Stage, number>>({
    target: 0,
    education: 0,
    solution: 0,
    evaluation: 0,
    ready_to_buy: 0,
  });

  useEventsChannel<LeadCreatedEvent>(event => {
    if (event.type === 'lead_created') {
      setNewLead(prev => ({
        ...prev,
        [event.payload.stage]: (prev[event.payload.stage] || 0) + 1,
      }));
    }
  });

  const getHeight = (count: number) => {
    if (scrollProgress >= 0.2) return 20;
    if (count === 0) return 20;

    const height = Math.round((count / maxCount) * 100);

    return height;
  };

  if (pipeline === 'hidden') {
    return null;
  }

  return (
    <div
      className={cn(
        'w-full items-center justify-center mb-2 mt-2 p-1 hidden md:flex max-w-[800px] mx-auto bg-primary-25 rounded-[8px] transition-all duration-200',
        scrollProgress > 0.2 && 'rounded-md'
      )}
    >
      {stageOptionsWithoutCustomer.map((stage, index) => {
        const count = stageCounts[stage.value] || 0;

        return (
          <div
            key={stage.value}
            style={{
              height: getHeight(count),
              zIndex: 10 - index,
              maxHeight: '100px',
              minHeight: '20px',
            }}
            onClick={e => {
              e.stopPropagation();
              count > 0 && onStageClick(stage.value);
              setNewLead(prev => ({
                ...prev,
                [stage.value]: 0,
              }));
            }}
            className={cn(
              'flex-1 flex items-center justify-center bg-primary-100 cursor-pointer hover:bg-primary-200 duration-300',
              index === 0 && 'rounded-l-md',
              index === stageOptionsWithoutCustomer.length - 1 && 'rounded-r-md',
              selectedStage === stage.value && 'bg-primary-200',
              count === 0 && 'cursor-not-allowed hover:bg-primary-100'
            )}
          >
            <div className="flex text-center text-primary-700 select-none items-center">
              <Icon
                name={stageIcons[stage.value]}
                className={cn(
                  'size-[14px] text-primary-700 mr-2 transition-all duration-300',
                  group !== 'stage' && 'animate-fadeIn w-[14px] opacity-100',
                  group === 'stage' && 'animate-fadeOut w-0 opacity-0'
                )}
              />
              <div className={cn('flex items-center gap-2', lead && 'truncate max-w-[70px]')}>
                {stage.label}
                {!lead && (
                  <>
                    <span>{count}</span>
                    {newLead[stage.value] > 0 && (
                      <div className="size-1 bg-primary-500 rounded-full" />
                    )}
                  </>
                )}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
};
