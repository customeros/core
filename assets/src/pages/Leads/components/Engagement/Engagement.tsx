import { usePage } from '@inertiajs/react';

import { cn } from 'src/utils/cn';
import upperFirst from 'lodash/upperFirst';
import { Icon } from 'src/components/Icon';
import { PageProps } from '@inertiajs/core';
import { ChannelAttribution } from 'src/types';
import { FeaturedIcon } from 'src/components/FeaturedIcon/FeaturedIcon';

const colorMap = {
  paid_social: 'text-warning-500',
  organic_social: 'text-orange-dark-500',
  email: 'text-violet-500',
  referral: 'text-pink-500',
  paid_search: 'text-blue-light-500',
  organic_search: 'text-blue-dark-500',
  direct: 'text-gray-700',
  workplace_tools: 'text-success-500',
};

const dotBgMap = {
  paid_social: 'bg-warning-500',
  organic_social: 'bg-orange-dark-500',
  email: 'bg-violet-500',
  referral: 'bg-pink-500',
  paid_search: 'bg-blue-light-500',
  organic_search: 'bg-blue-dark-500',
  direct: 'bg-gray-700',
  workplace_tools: 'bg-success-500',
};

const channelLabelMap = {
  paid_social: 'Paid Social',
  organic_social: 'Organic Social',
  email: 'Email',
  referral: 'Referral',
  paid_search: 'Paid Search',
  organic_search: 'Organic Search',
  direct: 'Direct',
  workplace_tools: 'Workplace Tools',
};

const EmptyState = () => {
  return (
    <div className="flex flex-col items-center justify-center w-full">
      <FeaturedIcon className="mb-6 mt-[40px]">
        <Icon name="activity" />
      </FeaturedIcon>
      <div className="font-medium text-base mb-2">No engagement yet</div>
      <div className="max-w-[340px] text-center">
        We haven’t seen any engagement from this lead yet. When they visit or interact with your
        website, you’ll see it here.
      </div>
    </div>
  );
};

export const Engagement = () => {
  const page = usePage<PageProps & { attributions_list: ChannelAttribution[] }>();

  if (!page.props.attributions_list || page.props.attributions_list.length === 0) {
    return <EmptyState />;
  }

  return (
    <div className="flex flex-col gap-2">
      <p className="text-sm font-medium">Engagement summary</p>
      <div className="flex flex-col gap-1 mt-4">
        {page.props.attributions_list
          .sort((a, b) => {
            return new Date(b.inserted_at).getTime() - new Date(a.inserted_at).getTime();
          })
          .map((attribution, idx) => {
            const channel = attribution.channel || 'direct';
            const isLast = idx === page.props.attributions_list.length - 1;

            return (
              <div key={idx} className="flex flex-row items-stretch">
                <div className="flex flex-col items-center mr-2 ">
                  <div
                    className={cn(
                      'size-1.5 rounded-full mt-[7px]',
                      dotBgMap[channel as keyof typeof dotBgMap]
                    )}
                  />
                  {!isLast && <div className="w-px min-h-2 flex-1 bg-gray-200 my-1 mb-[-7px]" />}
                </div>
                <div className="flex-1 flex flex-col gap-1">
                  <div className="flex flex-wrap items-center gap-1">
                    <span
                      className={cn('font-semibold', colorMap[channel as keyof typeof colorMap])}
                    >
                      {channelLabelMap[channel as keyof typeof channelLabelMap] || channel}
                    </span>
                    <span className="text-gray-500">•</span>
                    <span>
                      {attribution.city && attribution.country_code
                        ? `${attribution.city}, ${attribution.country_code}`
                        : attribution.city || attribution.country_code || ''}
                    </span>
                    <span className="text-gray-500">•</span>
                    <span className="text-gray-500">{attribution.inserted_at}</span>
                  </div>
                  <div className="pl-4 flex flex-col gap-0.5 text-sm">
                    {(attribution.platform !== null ||
                      (attribution.referrer && attribution.referrer !== '')) && (
                      <div className="flex items-center gap-1">
                        <Icon name="corner-down-right" />
                        <span className="text-gray-700">
                          {attribution.platform !== null ? 'Via' : 'From'}
                        </span>
                        <span>
                          {attribution.platform !== null
                            ? upperFirst(attribution.platform)
                            : attribution.referrer}
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
      </div>
    </div>
  );
};
