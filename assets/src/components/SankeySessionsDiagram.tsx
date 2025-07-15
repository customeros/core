/* eslint-disable @typescript-eslint/no-explicit-any */
import { useRef, useState, useEffect } from 'react';

import * as d3 from 'd3';
import { SessionAnalytics } from 'src/types';
import { useUrlState } from 'src/hooks/useUrlState';
import { AnalyticsUrlState } from 'src/pages/Analytics/Analytics';
import {
  SankeyLink,
  SankeyNode,
  sankeyLeft,
  SankeyGraph,
  sankey as d3Sankey,
  sankeyLinkHorizontal,
} from 'd3-sankey';

import Wheel from './Wheel';

interface SankeySessionsDiagramProps {
  width?: number;
  height?: number;
  session_analytics: SessionAnalytics[];
}

// Color mapping for all hex colors used in the diagram
const COLOR_MAP = {
  gray100: '#f3f4f6',
  gray200: '#e5e7eb',
  green200: '#bbf7d0',
  green300: '#86efac',
  green400: '#4ade80',
  green500: '#22c55e',
};

const NODE_MAP = {
  'All Sessions': COLOR_MAP.gray200,
  Identified: COLOR_MAP.green300,
  'Non-identified': COLOR_MAP.gray200,
  'ICP Fit': COLOR_MAP.green400,
  'Non ICP Fit': COLOR_MAP.gray200,
  New: COLOR_MAP.green500,
  Returning: COLOR_MAP.green500,
};

type SankeyNodeData = {
  name: string;
  color: string;
  rawValue: number;
};

type SankeyLinkData = {
  color: string;
  source: number;
  target: number;
};

function buildSankeyData(session: SessionAnalytics) {
  const newIcpFitLeads = session.new_icp_fit_leads;
  const allSessions = session.sessions;
  const identified = session.identified_sessions;
  const nonIdentified = allSessions - identified;
  const icpFit = session.icp_fit_sessions;
  const nonIcpFit = identified - icpFit;
  const returning = icpFit - newIcpFitLeads;

  const values = {
    'All Sessions': allSessions,
    Identified: identified,
    'Non-identified': nonIdentified,
    'ICP Fit': icpFit,
    'Non ICP Fit': nonIcpFit,
    New: newIcpFitLeads,
    Returning: returning,
  };

  const minValue = Math.min(...Object.values(values));
  const maxValue = Math.max(...Object.values(values));

  const scale = d3.scaleLinear().domain([minValue, maxValue]).range([100, 300]).clamp(false);

  const nodes = Object.entries(NODE_MAP).map(([name, color], index) => ({
    name,
    index,
    color,
    rawValue: values[name as keyof typeof values],
  }));
  const links = [
    {
      source: 0,
      target: 1,
      value: scale(identified),
      color: COLOR_MAP.green200, // green-200
    }, // All Sessions -> Identified
    {
      source: 0,
      target: 2,
      value: scale(nonIdentified),
      color: COLOR_MAP.gray100, // gray-100
    }, // All Sessions -> Non-identified
    {
      source: 1,
      target: 3,
      value: scale(icpFit),
      color: COLOR_MAP.green300, // green-300
    }, // Identified -> ICP Fit
    {
      source: 1,
      target: 4,
      value: scale(nonIcpFit),
      color: COLOR_MAP.gray100, // gray-100
    }, // Identified -> Non ICP Fit
    {
      source: 3,
      target: 5,
      value: scale(newIcpFitLeads),
      color: newIcpFitLeads > 0 ? COLOR_MAP.green400 : COLOR_MAP.gray100, // green-400 or gray-100
    }, // ICP Fit -> New
    {
      source: 3,
      target: 6,
      value: scale(returning),
      color: COLOR_MAP.green400, // green-400
    }, // ICP Fit -> Returning
  ];

  return { nodes, links, values };
}

function buildDefaultSankeyData() {
  // Default values to show the structure when no data is available
  const defaultValues = {
    'All Sessions': 0,
    Identified: 0,
    'Non-identified': 0,
    'ICP Fit': 0,
    'Non ICP Fit': 0,
    New: 0,
    Returning: 0,
  };

  const scale = d3.scaleLinear().domain([15, 100]).range([100, 300]).clamp(false);

  const nodes = Object.entries(NODE_MAP).map(([name, color], index) => ({
    name,
    index,
    color: COLOR_MAP.gray200, // All nodes gray for fallback
    rawValue: defaultValues[name as keyof typeof defaultValues],
  }));

  const links = [
    {
      source: 0,
      target: 1,
      value: scale(defaultValues.Identified),
      color: COLOR_MAP.gray100, // gray-100
    }, // All Sessions -> Identified
    {
      source: 0,
      target: 2,
      value: scale(defaultValues['Non-identified']),
      color: COLOR_MAP.gray100, // gray-100
    }, // All Sessions -> Non-identified
    {
      source: 1,
      target: 3,
      value: scale(defaultValues['ICP Fit']),
      color: COLOR_MAP.gray100, // gray-100
    }, // Identified -> ICP Fit
    {
      source: 1,
      target: 4,
      value: scale(defaultValues['Non ICP Fit']),
      color: COLOR_MAP.gray100, // gray-100
    }, // Identified -> Non ICP Fit
    {
      source: 3,
      target: 5,
      value: scale(defaultValues.New),
      color: COLOR_MAP.gray100, // gray-100
    }, // ICP Fit -> New
    {
      source: 3,
      target: 6,
      value: scale(defaultValues.Returning),
      color: COLOR_MAP.gray100, // gray-100
    }, // ICP Fit -> Returning
  ];

  return { nodes, links, values: defaultValues };
}

export const SankeySessionsDiagram = ({
  width = 1000,
  height = 300,
  session_analytics,
}: SankeySessionsDiagramProps) => {
  const ref = useRef<SVGSVGElement | null>(null);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [isInitialized, setIsInitialized] = useState(false);
  const { getUrlState } = useUrlState<AnalyticsUrlState>();
  const { time_range } = getUrlState();

  useEffect(() => {
    setSelectedIndex(0);

    const hasData = session_analytics.length > 0;
    const session = hasData ? session_analytics[selectedIndex] : null;
    const { nodes, links } = hasData ? buildSankeyData(session!) : buildDefaultSankeyData();

    if (!isInitialized) {
      d3.select(ref.current).selectAll('*').remove();
      setIsInitialized(true);
    }

    // Sankey setup
    const sankey = d3Sankey()
      .nodeWidth(8)
      .nodePadding(16)
      .nodeAlign(sankeyLeft)
      .nodeSort((a, b) => {
        return (a.index ?? 0) - (b.index ?? 0);
      })
      .linkSort((a, b) => {
        const aSource = typeof a.source === 'number' ? a.source : (a.source as any).index;
        const bSource = typeof b.source === 'number' ? b.source : (b.source as any).index;
        const aTarget = typeof a.target === 'number' ? a.target : (a.target as any).index;
        const bTarget = typeof b.target === 'number' ? b.target : (b.target as any).index;

        if (aSource !== bSource) {
          return aSource - bSource;
        }

        return aTarget - bTarget;
      })
      .extent([
        [0, 0],
        [width - 100, height],
      ]);

    const sankeyData = sankey({
      nodes: nodes.map(d => Object.assign({}, d) as SankeyNode<SankeyNodeData, SankeyLinkData>),
      links: links.map(d => Object.assign({}, d) as SankeyLink<SankeyNodeData, SankeyLinkData>),
    }) as SankeyGraph<SankeyNodeData, SankeyLinkData>;

    const svg = d3.select(ref.current);

    const duration = 500;

    if (!isInitialized) {
      // Initial render - no animation
      svg
        .append('g')
        .attr('fill', 'none')
        .attr('stroke-opacity', 1)
        .selectAll('path')
        .data(sankeyData.links)
        .join('path')
        .attr('d', sankeyLinkHorizontal())
        .attr('stroke', d => (d.value > 100 ? d.color : COLOR_MAP.gray100))
        .attr('stroke-width', d => Math.max(0, d.width ?? 0))
        .attr('stroke-dasharray', d => (!hasData ? (d.value > 100 ? '0' : '3') : 'none'))
        .attr('opacity', 1);

      // Draw nodes
      const node = svg
        .append('g')
        .selectAll('g')
        .data(sankeyData.nodes)
        .join('g')
        .attr('transform', d => `translate(${d.x0},${d.y0})`);

      node
        .append('rect')
        .attr('height', d => (d.y1 ?? 0) - (d.y0 ?? 0))
        .attr('width', d => (d.x1 ?? 0) - (d.x0 ?? 0))
        .attr('fill', d => (d.rawValue > 0 ? d.color : COLOR_MAP.gray100))
        .attr('id', 'node');

      node
        .append('rect')
        .attr('height', 16)
        .attr('width', 16)
        .attr('x', d => (d.x1 ?? 0) - (d.x0 ?? 0) - 36)
        .attr('y', d => ((d.y1 ?? 0) - (d.y0 ?? 0)) / 2 - 8)
        .attr('rx', 8)
        .attr('ry', 8)
        .attr('fill', (d: any) => 'transparent')
        .attr('id', 'label');

      node
        .append('text')
        .attr('x', d => (d.x1 ?? 0) - (d.x0 ?? 0) + 8)
        .attr('y', 12)
        .attr('dy', '0.35em')
        .attr('text-anchor', 'start')
        .style('font', '16px')
        .style('text-transform', 'uppercase')
        .text(d => d.name);

      node
        .append('text')
        .attr('id', 'value')
        .attr('x', d => (d.x1 ?? 0) - (d.x0 ?? 0) + 8)
        .attr('y', 32)
        .attr('dy', '0.35em')
        .attr('text-anchor', 'start')
        .style('font', '16px')
        .style('text-transform', 'uppercase')
        .text(d => d.rawValue);
    } else {
      // Animated update
      const linkGroup = svg.select('g');
      const linkPaths = linkGroup.selectAll('path');

      linkPaths
        .data(sankeyData.links)
        .transition()
        .duration(duration)
        .ease(d3.easeExpInOut)
        .attr('d', sankeyLinkHorizontal())
        .attr('stroke-width', d => Math.max(0, d.width ?? 0))
        .attr('stroke', (d: any) => (d.value > 100 ? d.color : COLOR_MAP.gray100))
        .attr('stroke-dasharray', d => (!hasData ? (d.value > 100 ? '0' : '3') : 'none'));

      const nodeGroup = svg.selectAll('g').filter(function () {
        return d3.select(this).select('rect').size() > 0;
      });

      const nodeGroups = nodeGroup.selectAll('g');

      nodeGroups
        .data(sankeyData.nodes)
        .transition()
        .duration(duration)
        .ease(d3.easeExpInOut)
        .attr('transform', d => `translate(${d.x0},${d.y0})`);

      nodeGroups
        .select('#node')
        .transition()
        .duration(duration)
        .ease(d3.easeExpInOut)
        .attr('height', (d: any) => (d.y1 ?? 0) - (d.y0 ?? 0))
        .attr('width', (d: any) => (d.x1 ?? 0) - (d.x0 ?? 0))
        .attr('fill', (d: any) => (d.rawValue > 0 ? d.color : COLOR_MAP.gray100));

      nodeGroups
        .select('#label')
        .transition()
        .duration(duration)
        .ease(d3.easeExpInOut)
        .attr('x', (d: any) => (d.x1 ?? 0) - (d.x0 ?? 0) - 36)
        .attr('y', (d: any) => ((d.y1 ?? 0) - (d.y0 ?? 0)) / 2 - 8);

      nodeGroups
        .select('text')
        .transition()
        .duration(duration)
        .ease(d3.easeExpInOut)
        .attr('x', (d: any) => (d.x1 ?? 0) - (d.x0 ?? 0) + 8)
        .attr('y', 12)
        .text((d: any) => d.name);

      nodeGroups
        .select('#value')
        .transition()
        .duration(duration)
        .ease(d3.easeExpInOut)
        .text((d: any) => d.rawValue);
    }
  }, [session_analytics, width, height, session_analytics.length, selectedIndex, isInitialized]);

  return (
    <>
      <svg ref={ref} width={width} height={height} className="mx-auto" />
      {session_analytics.length >= 0 && (
        <div style={{ width: width }} className="h-[40px] mt-4 mx-auto">
          <Wheel
            loop={false}
            width={width}
            key={time_range}
            initIdx={selectedIndex}
            values={session_analytics.map(s => s?.bucket_start_at)}
            onValueChange={value => {
              setSelectedIndex(Number(value));
            }}
          />
        </div>
      )}
    </>
  );
};

export default SankeySessionsDiagram;
