import { useEffect } from 'react';

import { cn } from 'src/utils/cn';
import { useUrlState } from 'src/hooks';
import { Lead, Stage, UrlState } from 'src/types';
import { Icon, IconName } from 'src/components/Icon/Icon';

import { stageIcons, stageOptions } from '../util';

interface PipelineProps {
  max_count: number;
  scroll_progress: number;
  stage_counts: Record<Stage, number>;
  leads: Lead[] | Record<Stage, Lead[]>;
  onStageClick: (stage: Stage | null) => void;
}

export const Pipeline = ({
  leads,
  stage_counts,
  scroll_progress,
  max_count,
  onStageClick,
}: PipelineProps) => {
  const { getUrlState } = useUrlState<UrlState>();
  const { pipeline, stage: selectedStage, group } = getUrlState();

  const getHeight = (count: number) => {
    return scroll_progress < 0.2 ? `${count ? (count / max_count) * 100 + 10 : 20}px` : '20px';
  };

  useEffect(() => {
    // ... existing code ...
  }, [scroll_progress, max_count]);

  if (pipeline === 'hidden') {
    return null;
  }

  return (
    <div
      className={cn(
        'w-full items-center justify-center mb-2 mt-2 p-1 hidden md:flex max-w-[800px] mx-auto bg-primary-25 rounded-[8px] transition-all duration-200',
        scroll_progress > 0.2 && 'rounded-md'
      )}
    >
      {stageOptions.map((stage, index) => {
        const count = stage_counts[stage.value as Stage] || 0;
        const prevCount = stage_counts[stageOptions[index - 1]?.value as Stage] || 0;
        const nextCount = stage_counts[stageOptions[index + 1]?.value as Stage] || 0;

        return (
          <div
            key={stage.value}
            onClick={e => {
              e.stopPropagation();
              count > 0 && onStageClick(stage.value as Stage);
            }}
            style={{
              height: getHeight(count),
              zIndex: 10 - index,
              maxHeight: '100px',
              minHeight: '20px',
            }}
            className={cn(
              'flex-1 flex items-center justify-center bg-primary-100 cursor-pointer hover:bg-primary-200 duration-300',
              scroll_progress < 0.2 &&
                count > nextCount &&
                (count - nextCount < 5 ? 'rounded-r-xs' : 'rounded-r-md'),
              scroll_progress < 0.2 &&
                count > prevCount &&
                (count - prevCount < 5 ? 'rounded-l-xs' : 'rounded-l-md'),
              scroll_progress > 0.2 &&
                index === 0 &&
                (count - nextCount > 5 ? 'rounded-l-xs' : 'rounded-l-md'),
              scroll_progress > 0.2 &&
                index === stageOptions.length - 1 &&
                (count - prevCount > 5 ? 'rounded-r-xs' : 'rounded-r-md'),
              selectedStage === stage.value && 'bg-primary-200',
              count === 0 && 'cursor-not-allowed hover:bg-primary-100'
            )}
          >
            <div className="flex text-center text-primary-700 select-none items-center">
              <Icon
                name={stageIcons[stage.value] as IconName}
                className={cn(
                  'size-[14px] text-primary-700 mr-2 transition-all duration-300',
                  group !== 'stage' && 'animate-fadeIn w-[14px] opacity-100',
                  group === 'stage' && 'animate-fadeOut w-0 opacity-0'
                )}
              />
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
  );
};
