import { usePage, WhenVisible } from '@inertiajs/react';

import { match } from 'ts-pattern';
import upperFirst from 'lodash/upperFirst';
import { Tooltip } from 'src/components/Tooltip';
import { ChannelAttribution as ChannelAttributionType } from 'src/types';

export const ChannelAttribution = () => {
  const page = usePage<{ attribution: ChannelAttributionType }>();
  const channelAttribution = page.props.attribution;

  const channelDisplay = match(channelAttribution?.channel)
    .with('paid_social', () => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-warning-500 rounded-full" />
        <span className="text-[14px]">Paid Social</span>
      </div>
    ))
    .with('organic_social', () => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-orange-dark-500 rounded-full" />
        <span className="text-[14px]">Organic Social</span>
      </div>
    ))
    .with('email', () => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-violet-500 rounded-full" />
        <span className="text-[14px]">Email</span>
      </div>
    ))
    .with('referral', () => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-pink-500 rounded-full" />
        <span className="text-[14px]">Referral</span>
      </div>
    ))
    .with('paid_search', () => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-blue-light-500 rounded-full" />
        <span className="text-[14px]">Paid Search</span>
      </div>
    ))
    .with('organic_search', () => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-blue-dark-500 rounded-full" />
        <span className="text-[14px]">Organic Search</span>
      </div>
    ))
    .with('direct', () => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-gray-500 rounded-full" />
        <span className="text-[14px]">Direct</span>
      </div>
    ))
    .otherwise(() => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-gray-500 rounded-full" />
        <span className="text-[14px]">Direct</span>
      </div>
    ));
  const showTooltip =
    channelAttribution?.channel !== 'direct' &&
    channelAttribution?.channel !== 'email' &&
    (channelAttribution?.referrer || channelAttribution?.platform);

  let tooltipLabel = '';

  if (channelAttribution?.referrer && channelAttribution?.platform) {
    tooltipLabel = `Via ${upperFirst(channelAttribution.platform)} · ${channelAttribution.referrer}`;
  } else if (channelAttribution?.referrer) {
    tooltipLabel = `From ${channelAttribution.referrer}`;
  } else if (channelAttribution?.platform) {
    tooltipLabel = `Via ${upperFirst(channelAttribution.platform)}`;
  }

  const content = (
    <div className="bg-gray-100 min-w-fit rounded-sm text-[14px] px-2 py-1 cursor-default hidden sm:flex md:flex lg:flex xl:flex 2xl:flex">
      {channelDisplay}
    </div>
  );

  return showTooltip ? (
    <WhenVisible fallback={<></>} data="attribution">
      <Tooltip side="bottom" label={tooltipLabel}>
        {content}
      </Tooltip>
    </WhenVisible>
  ) : (
    content
  );
};
