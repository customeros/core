import type { Stage, UrlState } from 'src/types';

import { useState } from 'react';

import { cn } from 'src/utils/cn';
import { Icon } from 'src/components/Icon/Icon';
import { useUrlState, useEventsChannel, LeadCreatedEvent } from 'src/hooks';

import { stageIcons, stageOptions } from '../util';

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
  const { pipeline, stage: selectedStage = 'target', group } = getUrlState();
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
        'w-full items-center justify-center mb-2 mt-2 p-1 flex max-w-[800px] mx-auto bg-primary-25 rounded-[8px] transition-all duration-200',
        scrollProgress > 0.2 && 'rounded-md'
      )}
    >
      {stageOptions.map((stage, index) => {
        const count = stageCounts[stage.value] || 0;

        return (
          <div
            key={stage.value}
            style={{
              height: getHeight(count),
              zIndex: 10 - index,
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
              'flex-1 flex items-center justify-center bg-primary-100 cursor-pointer hover:bg-primary-200 duration-300 max-h-[20px] min-h-[20px] md:max-h-[100px]',
              index === 0 && 'rounded-l-md',
              index === stageOptions.length - 1 && 'rounded-r-md',
              selectedStage === stage.value && 'bg-primary-200',
              count === 0 && 'cursor-not-allowed hover:bg-primary-100'
            )}
          >
            <div
              className={cn(
                'flex text-center text-primary-700 select-none items-center',
                newLead[stage.value] > 0 && 'animate-pulse md:animate-none'
              )}
            >
              <Icon
                name={stageIcons[stage.value]}
                className={cn(
                  'size-[14px] text-primary-700 mr-2 transition-all duration-300 hidden md:block',
                  group !== 'stage' && 'animate-fadeIn w-[14px] opacity-100',
                  group === 'stage' && 'animate-fadeOut w-0 opacity-0'
                )}
              />
              <div className="flex relative items-center gap-2">
                <span className="line-clamp-1 truncate">{stage.label}</span>
                <span
                  className={cn(
                    'hidden md:inline',
                    newLead[stage.value] > 0 &&
                      'after:content-[""] after:size-1 after:bg-primary-500 after:hidden md:after:block after:rounded-full after:absolute after:left-full after:top-1/2 after:-translate-y-1/2 after:ml-1'
                  )}
                >
                  {count}
                </span>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
};
