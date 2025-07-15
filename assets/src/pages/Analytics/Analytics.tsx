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
  const { setUrlState, getUrlState } = useUrlState<AnalyticsUrlState>();

  const { time_range } = getUrlState();

  const handleTimeRangeChange = (time_range: AnalyticsUrlState['time_range']) => {
    setUrlState(prev => ({ ...prev, time_range }));
  };

  const isTimeRangeActive = (range: AnalyticsUrlState['time_range']) => {
    return time_range === range ? 'active' : 'inactive';
  };

  const totalLeads = session_analytics.reduce(
    (acc, curr) => acc + (curr.new_icp_fit_leads ?? 0),
    0
  );
  const totalSessions = session_analytics.reduce((acc, curr) => acc + (curr.sessions ?? 0), 0);
  const totalCompanies = session_analytics.reduce(
    (acc, curr) => acc + (curr.unique_companies ?? 0),
    0
  );
  const totalIcpFitSessions = session_analytics.reduce(
    (acc, curr) => acc + (curr.icp_fit_sessions ?? 0),
    0
  );

  const sessionIdentificationRate =
    session_analytics.length > 0
      ? `${((totalIcpFitSessions / totalSessions) * 100).toFixed(2)}%`
      : '0%';
  const icpQualificationRate =
    session_analytics.length > 0 ? `${((totalLeads / totalCompanies) * 100).toFixed(2)}%` : '0%';

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
            onClick={() => handleTimeRangeChange('hour')}
          >
            24 hour
          </Button>
          <Button
            size="xxs"
            className="w-fit"
            data-state={isTimeRangeActive('day')}
            onClick={() => handleTimeRangeChange('day')}
          >
            7 days
          </Button>
          <Button
            size="xxs"
            className="w-fit"
            data-state={isTimeRangeActive('week')}
            onClick={() => handleTimeRangeChange('week')}
          >
            4 weeks
          </Button>
          <Button
            size="xxs"
            className="w-fit"
            data-state={isTimeRangeActive('month')}
            onClick={() => handleTimeRangeChange('month')}
          >
            3 months
          </Button>
        </Tabs>
        <div ref={ref} className="md:w-full h-[224px] 2xl:h-[300px] 2xl:w-[1440px]">
          {dimensions && (
            <SankeySessionsDiagram
              height={dimensions?.height}
              session_analytics={session_analytics}
              width={dimensions?.width <= 1500 ? dimensions?.width - 200 : dimensions?.width}
            />
          )}
        </div>
      </div>
    </RootLayout>
  );
}
