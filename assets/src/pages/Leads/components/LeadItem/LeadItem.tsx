import { cn } from 'src/utils/cn';
import { useOnLongHover } from 'rooks';
import { useUrlState } from 'src/hooks';
import { useLocalstorageState } from 'rooks';
import { Tooltip } from 'src/components/Tooltip';
import { Lead, Stage, UrlState } from 'src/types';
import { Icon, IconName } from 'src/components/Icon/Icon';

import { stageIcons } from '../util';

interface LeadItemProps {
  lead: Lead;
  isSeen: boolean;
  handleStageClick: (stage: Stage | null) => void;
  handleOpenLead: (lead: { id: string; stage: Stage }) => void;
}
const leadStateMap = {
  not_contacted_yet: { label: 'Not contacted yet', icon: '' },
  outreach_in_progress: { label: 'Outreach in progress', icon: 'clock-fast-forward' },
  meeting_booked: { label: 'Meeting booked', icon: 'calendar-check-01' },
};

export const LeadItem = ({ lead, isSeen, handleOpenLead, handleStageClick }: LeadItemProps) => {
  const { getUrlState } = useUrlState<UrlState>();
  const { lead: selectedLead, group, stage: selectedStage } = getUrlState();
  const [_, setSeen] = useLocalstorageState('seen-leads', {});
  const longHoverRef = useOnLongHover(
    () => {
      setSeen(prev => ({ ...prev, [lead.id]: true }));
    },
    { duration: 500 }
  );

  const isSelected = selectedLead === lead.id;

  const leadDate = new Date(lead.inserted_at);
  const now = new Date();
  const timeDifference = now.getTime() - leadDate.getTime();
  const hoursDifference = timeDifference / (1000 * 60 * 60);
  const isOlderThan24Hours = hoursDifference > 24;

  return (
    <div
      key={lead.id}
      className={cn(
        'flex items-center w-full relative group hover:bg-gray-50 animate-slideUpFade',
        isSelected && 'bg-gray-100'
      )}
    >
      <div className={cn('ml-6 size-6', (group === 'stage' || !group) && 'hidden')}>
        <Icon
          name={stageIcons[lead.stage] as IconName}
          className="size-[14px] text-gray-500 hover:text-primary-700 transition-colors cursor-pointer"
          onClick={() => {
            handleStageClick(selectedStage === lead.stage ? null : lead.stage);
          }}
        />
      </div>
      <div
        className={cn(
          'flex items-center gap-2 ml-2 flex-1 md:flex-none md:flex-shrink-0 bg-white group-hover:bg-gray-50',
          isSelected && 'bg-gray-100',
          (group === 'stage' || !group) && 'ml-5'
        )}
      >
        {lead.icon ? (
          <div
            className={cn('relative size-6 flex cursor-pointer')}
            onClick={() => {
              handleOpenLead({ id: lead.id, stage: lead.stage });
            }}
          >
            <img
              loading="lazy"
              key={lead.icon}
              src={lead.icon}
              alt={lead.name}
              className="size-6 object-contain border border-gray-200 rounded flex-shrink-0"
            />
            {lead?.state !== 'not_contacted_yet' && (
              <span className="absolute bottom-[-3px] left-[14px] z-20 flex items-center justify-center bg-white size-4 rounded-full ring-white">
                <Icon
                  className="w-3 h-3" // or "size-3" if you have that utility
                  name={leadStateMap[lead.state as keyof typeof leadStateMap].icon as IconName}
                />
              </span>
            )}
          </div>
        ) : (
          <div
            className={cn(
              'relative size-6 flex items-center justify-center border border-gray-200 rounded flex-shrink-0 cursor-pointer'
            )}
          >
            <Icon
              name="building-06"
              onClick={() => {
                handleOpenLead({ id: lead.id, stage: lead.stage });
              }}
            />
            {lead?.state !== 'not_contacted_yet' && (
              <span className="absolute bottom-[-3px] left-[14px] z-20 flex items-center justify-center bg-white size-4 rounded-full  ring-white">
                <Icon
                  className="w-3 h-3" // or "size-3" if you have that utility
                  name={leadStateMap[lead.state as keyof typeof leadStateMap].icon as IconName}
                />
              </span>
            )}
          </div>
        )}
        <p
          className={cn('py-2 px-2 font-medium truncate cursor-pointer')}
          onClick={() => {
            handleOpenLead({ id: lead.id, stage: lead.stage });
            setSeen(prev => ({ ...prev, [lead.id]: true }));
          }}
        >
          {lead.name || 'Unnamed'}
        </p>
        {!isSeen && !isOlderThan24Hours && (
          <div ref={longHoverRef} className="p-3 rounded-sm hover:bg-gray-100 transition-colors">
            <div className="size-1 bg-primary-500 rounded-full" />
          </div>
        )}
      </div>
      <div
        className={cn(
          'flex-4 text-right mr-4 min-w-0 flex-shrink-0 bg-white hidden md:block group-hover:bg-gray-50',
          isSelected && 'bg-gray-100'
        )}
      >
        {lead.industry && (
          <span className="bg-gray-100 w-fit px-2 py-1 rounded-[4px] max-w-[100px] truncate">
            {lead.industry}
          </span>
        )}
      </div>

      <p
        onClick={() => {
          window.open(`https://${lead.domain}`, '_blank');
        }}
        className={cn(
          'text-right cursor-pointer hover:underline min-w-0 flex-1 md:flex-none md:flex-shrink-0 bg-white px-2 py-1 group-hover:bg-gray-50 truncate',
          isSelected && 'bg-gray-100'
        )}
      >
        {lead.domain}
      </p>
      <Tooltip label={lead.country_name ?? 'Country not found'}>
        <p
          className={cn(
            'text-center text-gray-500 flex-shrink-0 bg-white py-2 pl-1 pr-5 group-hover:bg-gray-50',
            isSelected && 'bg-gray-100'
          )}
        >
          {countryCodeToEmoji(lead.country)}
        </p>
      </Tooltip>
    </div>
  );
};

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
