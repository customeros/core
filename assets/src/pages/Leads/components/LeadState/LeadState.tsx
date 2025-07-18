import { usePage } from '@inertiajs/react';

import axios from 'axios';
import { Lead } from 'src/types';
import { Button } from 'src/components/Button';
import { toastSuccess } from 'src/components/Toast';
import { Icon, IconName } from 'src/components/Icon';
import { Popover, PopoverContent, PopoverTrigger } from 'src/components/Popover';

const leadStateMap = [
  {
    value: 'not_contacted_yet',
    label: 'Not contacted yet',
  },
  {
    value: 'outreach_in_progress',
    label: 'Outreach in progress',
    icon: 'clock-fast-forward',
  },
  {
    value: 'meeting_booked',
    label: 'Meeting booked',
    icon: 'calendar-check-01',
  },
];

export const LeadState = ({ leadId }: { leadId: string }) => {
  const page = usePage<{ leads: Lead[] }>();

  const leadState = page.props.leads.find(lead => lead.id === leadId);

  const handleSelectState = (state: string) => {
    axios.patch(`/leads/${leadId}`, { state }).then(() => {
      toastSuccess('Lead state updated', 'lead-state-updated');
    });
  };

  const selectedState = leadStateMap.find(state => state.value === leadState?.state);

  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button
          size="xs"
          variant="outline"
          rightIcon={<Icon name="chevron-down" />}
          leftIcon={
            selectedState?.value !== 'not_contacted_yet' ? (
              <Icon name={selectedState?.icon as IconName} />
            ) : (
              <></>
            )
          }
        >
          {selectedState?.label}
        </Button>
      </PopoverTrigger>
      <PopoverContent className="max-w-[260px] min-w-[190px] py-1  top-[10px] max-h-[300px] overflow-y-auto">
        <div className="flex flex-col gap-1 mt-1 cursor-pointer">
          {leadStateMap.map(state => (
            <div
              key={state.value}
              onClick={() => handleSelectState(state.value)}
              className="flex items-center gap-2 py-1 justify-between hover:bg-gray-100 px-2 rounded-sm"
            >
              <div className="flex items-center gap-2">
                <span className="text-sm">{state.label}</span>
              </div>
              {leadState?.state === state.value && (
                <Icon name="check" className="text-primary-500" />
              )}
            </div>
          ))}
        </div>
      </PopoverContent>
    </Popover>
  );
};
