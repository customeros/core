import { useState } from 'react';

import { useDimensionsRef } from 'rooks';
import { Icon } from 'src/components/Icon';
import { SessionAnalytics } from 'src/types';
import { RootLayout } from 'src/layouts/Root';
import { Tabs } from 'src/components/Tabs/Tabs';
import { useUrlState } from 'src/hooks/useUrlState';
import { Button } from 'src/components/Button/Button';
import SankeySessionsDiagram from 'src/components/SankeySessionsDiagram';

interface AnalyticsProps {
  session_analytics: SessionAnalytics[];
}

export type AnalyticsUrlState = {
  time_range: 'hour' | 'day' | 'week' | 'month';
};

export default function Analytics({ session_analytics }: AnalyticsProps) {
  const [ref, dimensions] = useDimensionsRef();
  const [selectedIndex, setSelectedIndex] = useState(0);
  const { setUrlState, getUrlState } = useUrlState<AnalyticsUrlState>();

  const { time_range } = getUrlState();

  const handleTimeRangeChange = (time_range: AnalyticsUrlState['time_range']) => {
    setUrlState(prev => ({ ...prev, time_range }));
    setSelectedIndex(0);
  };

  const isTimeRangeActive = (range: AnalyticsUrlState['time_range']) => {
    return time_range === range ? 'active' : 'inactive';
  };

  const totalLeads = session_analytics[selectedIndex]?.new_icp_fit_leads ?? 0;

  const allSessions = session_analytics[selectedIndex]?.sessions ?? 0;
  const uniqueNewCompanies = session_analytics[selectedIndex]?.unique_new_companies ?? 0;
  const identifiedSessions = session_analytics[selectedIndex]?.identified_sessions ?? 0;

  const sessionIdentificationRate =
    allSessions > 0 ? `${((identifiedSessions / allSessions) * 100).toFixed(1)}%` : '0%';
  const icpQualificationRate =
    uniqueNewCompanies > 0 ? `${((totalLeads / uniqueNewCompanies) * 100).toFixed(1)}%` : '0%';

  const hasAnyData = session_analytics.some(s => s.sessions > 0);

  return (
    <RootLayout>
      <div className="relative flex flex-col gap-8 h-[calc(100vh-3rem)] overflow-x-hidden bg-white p-0 transition-[width] duration-300 ease-in-out w-full 2xl:w-[1440px] 2xl:mx-auto animate-fadeIn items-center">
        <div className="flex gap-4 w-full mt-8 px-6">
          <div className="flex-1 rounded-md p-4 border border-gray-200">
            <div className="flex items-center gap-2">
              <Icon className="size-5" name="activity-heart" />
              <p className="font-medium">No. of Leads Created</p>
            </div>
            <p className="pl-7 text-xl font-bold">{totalLeads}</p>
          </div>
          <div className="flex-1 rounded-md p-4 border border-gray-200">
            <div className="flex items-center gap-2">
              <Icon className="size-5" name="activity-heart" />
              <p className="font-medium">Session Identification Rate</p>
            </div>
            <p className="pl-6 text-xl font-bold">{sessionIdentificationRate}</p>
          </div>
          <div className="flex-1 rounded-md p-4 border border-gray-200">
            <div className="flex items-center gap-2">
              <Icon className="size-5" name="activity-heart" />
              <p className="font-medium">ICP Qualification Rate</p>
            </div>
            <p className="pl-6 text-xl font-bold">{icpQualificationRate}</p>
          </div>
        </div>
        <Tabs variant="enclosed">
          <Button
            size="xxs"
            className="w-fit"
            data-state={isTimeRangeActive('hour')}
            onClick={() => {
              handleTimeRangeChange('hour');
            }}
          >
            hourly
          </Button>
          <Button
            size="xxs"
            className="w-fit"
            data-state={isTimeRangeActive('day')}
            onClick={() => {
              handleTimeRangeChange('day');
            }}
          >
            daily
          </Button>
          <Button
            size="xxs"
            className="w-fit"
            data-state={isTimeRangeActive('week')}
            onClick={() => handleTimeRangeChange('week')}
          >
            weekly
          </Button>
          <Button
            size="xxs"
            className="w-fit"
            data-state={isTimeRangeActive('month')}
            onClick={() => handleTimeRangeChange('month')}
          >
            monthly
          </Button>
        </Tabs>
        <div ref={ref} className="md:w-full h-[224px] 2xl:h-[300px] 2xl:w-[1440px]">
          {dimensions && (
            <SankeySessionsDiagram
              hasData={hasAnyData}
              height={dimensions?.height}
              selectedIndex={selectedIndex}
              session_analytics={session_analytics[selectedIndex]}
              wheelLabels={session_analytics.map(s => s?.bucket_start_at)}
              width={dimensions?.width <= 1500 ? dimensions?.width - 200 : dimensions?.width}
              onSelectedIndexChange={index => {
                setSelectedIndex(index);
              }}
            />
          )}
        </div>
      </div>
    </RootLayout>
  );
}
