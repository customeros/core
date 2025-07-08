import { usePage, WhenVisible } from '@inertiajs/react';

import { match } from 'ts-pattern';
import { Tooltip } from 'src/components/Tooltip';
import { ChannelAttribution as ChannelAttributionType } from 'src/types';

export const ChannelAttribution = () => {
  const page = usePage<{ attribution: ChannelAttributionType }>();
  const channelAttribution = page.props.attribution;

  const channelDisplay = match(channelAttribution?.channel)
    .with('paid_social', () => (
      <div className="flex items-center gap-1">
        <p className="size-1 bg-warning-500 rounded-full" />
        <span className="text-xs">Paid Social</span>
      </div>
    ))
    .with('organic_social', () => (
      <div className="flex items-center gap-1">
        <p className="size-1 bg-orange-dark-500 rounded-full" />
        <span className="text-xs">Organic Social</span>
      </div>
    ))
    .with('email', () => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-violet-500 rounded-full" />
        <span className="text-xs">Email</span>
      </div>
    ))
    .with('referral', () => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-pink-500 rounded-full" />
        <span className="text-xs">Referrals</span>
      </div>
    ))
    .with('paid_search', () => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-blue-light-500 rounded-full" />
        <span className="text-xs">Paid Search</span>
      </div>
    ))
    .with('organic_search', () => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-blue-dark-500 rounded-full" />
        <span className="text-xs">Organic Search</span>
      </div>
    ))
    .with('direct', () => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-gray-500 rounded-full" />
        <span className="text-xs">Direct</span>
      </div>
    ))
    .otherwise(() => (
      <div className="flex items-center gap-1.5">
        <p className="size-2 bg-gray-300 rounded-full" />
        <span className="text-xs">Unknown channel</span>
      </div>
    ));
  const showTooltip =
    channelAttribution?.channel !== 'direct' &&
    channelAttribution?.channel !== 'email' &&
    (channelAttribution?.referrer || channelAttribution?.platform);

  let tooltipLabel = '';

  if (channelAttribution?.referrer && channelAttribution?.platform) {
    tooltipLabel = `Via ${channelAttribution.platform} · ${channelAttribution.referrer}`;
  } else if (channelAttribution?.referrer) {
    tooltipLabel = `Via ${channelAttribution.referrer}`;
  } else if (channelAttribution?.platform) {
    tooltipLabel = `Via ${channelAttribution.platform}`;
  }

  const content = (
    <div className="bg-gray-100 min-w-fit rounded-sm text-sm px-2 py-1.5 cursor-default hidden sm:flex md:flex lg:flex xl:flex 2xl:flex">
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
