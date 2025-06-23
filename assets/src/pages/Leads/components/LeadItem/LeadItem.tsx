import { cn } from 'src/utils/cn';
import { useUrlState } from 'src/hooks';
import { Tooltip } from 'src/components/Tooltip';
import { Lead, Stage, UrlState } from 'src/types';
import { Icon, IconName } from 'src/components/Icon/Icon';

import { stageIcons } from '../util';

interface LeadItemProps {
  lead: Lead;
  handleOpenLead: (lead: { id: string }) => void;
  handleStageClick: (stage: Stage | null) => void;
}

export const LeadItem = ({ lead, handleOpenLead, handleStageClick }: LeadItemProps) => {
  const { getUrlState } = useUrlState<UrlState>();
  const { lead: selectedLead, group, stage: selectedStage } = getUrlState();

  const isSelected = selectedLead === lead.id;

  return (
    <div
      key={lead.id}
      className={cn(
        'flex items-center w-full relative group hover:bg-gray-50 animate-slideUpFade',
        isSelected && 'bg-gray-50'
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
          'flex items-center gap-2 ml-2 min-w-0 flex-1 md:flex-none md:flex-shrink-0 bg-white group-hover:bg-gray-50',
          isSelected && 'bg-gray-50',
          (group === 'stage' || !group) && 'ml-5'
        )}
      >
        {lead.icon ? (
          <div
            className="relative cursor-pointer size-6 flex"
            onClick={() => {
              handleOpenLead(lead);
            }}
          >
            <img
              loading="lazy"
              key={lead.icon}
              src={lead.icon}
              alt={lead.name}
              className="size-6 object-contain border border-gray-200 rounded flex-shrink-0"
            />
            {lead?.icp_fit === 'strong' && (
              <Icon
                name="flame"
                className="absolute bottom-[-3px] left-[14px] w-[14px] h-[14px] z-20 text-error-500 ring-offset-1
                                        rounded-full ring-[1px] bg-error-100 ring-white"
              />
            )}
          </div>
        ) : (
          <div className="relative size-6 flex items-center justify-center border border-gray-200 rounded flex-shrink-0 cursor-pointer">
            <Icon
              name="building-06"
              onClick={() => {
                handleOpenLead(lead);
              }}
            />
            {lead?.icp_fit === 'strong' && (
              <Icon
                name="flame"
                className="absolute bottom-[-3px] left-[14px] w-[14px] h-[14px] z-20 text-error-500 ring-offset-1
                                        rounded-full ring-[1px] bg-error-100 ring-white"
              />
            )}
          </div>
        )}
        <p
          className="py-2 px-2 cursor-pointer font-medium truncate"
          onClick={() => {
            handleOpenLead(lead);
          }}
        >
          {lead.name || 'Unnamed'}
        </p>
      </div>
      <div
        className={cn(
          'flex-4 text-right mr-4 min-w-0 flex-shrink-0 bg-white hidden md:block group-hover:bg-gray-50',
          isSelected && 'bg-gray-50'
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
          isSelected && 'bg-gray-50'
        )}
      >
        {lead.domain}
      </p>
      <Tooltip label={lead.country_name ?? 'Country not found'}>
        <p
          className={cn(
            'text-center text-gray-500 flex-shrink-0 bg-white py-2 pl-1 pr-5 group-hover:bg-gray-50',
            isSelected && 'bg-gray-50'
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
