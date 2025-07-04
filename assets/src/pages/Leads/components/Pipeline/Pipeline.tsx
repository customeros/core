import type { Stage, UrlState } from 'src/types';

import { cn } from 'src/utils/cn';
import { useUrlState } from 'src/hooks';
import { twMerge } from 'tailwind-merge';
import { Icon, IconName } from 'src/components/Icon/Icon';

import { stageIcons, stageOptionsWithoutCustomer } from '../util';

interface PipelineProps {
  maxCount: number;
  scrollProgress: number;
  stageCounts: Record<Stage, number>;
  onStageClick: (stage: Stage | null) => void;
}

export const Pipeline = ({
  stageCounts,
  scrollProgress,
  maxCount,
  onStageClick,
}: PipelineProps) => {
  const { getUrlState } = useUrlState<UrlState>();
  const { pipeline, stage: selectedStage, group, lead } = getUrlState();

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
        const count = stageCounts[stage.value as Stage] || 0;
        const prevCount = stageCounts[stageOptionsWithoutCustomer[index - 1]?.value as Stage] || 0;
        const nextCount = stageCounts[stageOptionsWithoutCustomer[index + 1]?.value as Stage] || 0;
        const height = getHeight(count);
        const prevHeight = getHeight(prevCount);
        const nextHeight = getHeight(nextCount);

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

              (() => {
                let className = '';

                if (index === 0) {
                  className += ' rounded-l-md';
                }

                if (index === stageOptionsWithoutCustomer.length - 1) {
                  className += ' rounded-r-md';
                }

                if (scrollProgress < 0.2) {
                  if (height - nextHeight === 0) {
                    className += ' rounded-r-none';
                  }

                  if (height - prevHeight === 0) {
                    className += ' rounded-l-none';
                  }

                  if (height - nextHeight < 0) {
                    className += ' rounded-r-none';
                  } else {
                    if (height - nextHeight !== 0) {
                      className +=
                        Math.abs(height - nextHeight) > 2 ? ' rounded-r-xs' : ' rounded-r-md';
                    }
                  }

                  if (height - prevHeight < 0 && height - prevHeight !== 0) {
                    className += ' rounded-l-none';
                  } else {
                    if (height - prevHeight !== 0) {
                      className +=
                        Math.abs(height - prevHeight) < 2 ? ' rounded-l-xs' : ' rounded-l-md';
                    }
                  }

                  if (index === 0) {
                    className += ' rounded-l-md';
                  }

                  if (index === stageOptionsWithoutCustomer.length - 1) {
                    className += ' rounded-r-md';
                  }
                }

                return twMerge(className);
              })(),
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
              <span className={cn(lead && 'truncate max-w-[70px]')}>
                {stage.label}
                {!lead && (
                  <>
                    <span className="mx-1">•</span>
                    <span>{count}</span>
                  </>
                )}
              </span>
            </div>
          </div>
        );
      })}
    </div>
  );
};
