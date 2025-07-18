export type Stage = 'target' | 'education' | 'solution' | 'evaluation' | 'ready_to_buy';

export type Lead = {
  id: string;
  icon: string;
  name: string;
  stage: Stage;
  state: string;
  count: number;
  domain: string;
  country: string;
  industry: string;
  updated_at: string;
  document_id: string;
  inserted_at: string;
  country_name: string;
  icp_fit: 'strong' | 'moderate';
};

export type Tenant = {
  id: string;
  name: string;
  domain: string;
  updated_at: string;
  inserted_at: string;
  workspace_name: string;
  workspace_icon_key: string;
  webtracker_status: 'available' | 'not_available';
};

export type Profile = {
  id: string;
  domain: string;
  profile: string;
  tenant_id: string;
  updated_at: string;
  inserted_at: string;
  qualifying_attributes: string[];
};

export type User = {
  id: string;
  email: string;
  admin: boolean;
  tenant_id: string;
  updated_at: string;
  inserted_at: string;
  confirmed_at: string;
};

export type Document = {
  id: string;
  name: string;
  icon: string;
  body: string;
  color: string;
  ref_id: string;
  tenant_id: string;
  updated_at: string;
  inserted_at: string;
  lexical_state: string;
};

export type UrlState = {
  lead?: string;
  stage?: Stage;
  viewMode?: 'default' | 'focus';
  pipeline?: 'hidden' | 'visible';
  tab?: 'account' | 'engagement' | 'contacts';
  group?: 'stage' | 'industry' | 'country' | 'none';
  asc?: 'updated_at' | 'name' | 'industry' | 'stage' | 'country';
  desc?: 'updated_at' | 'name' | 'industry' | 'stage' | 'country';
};

export type IcpProfile = {
  profile: string;
  qualifying_attributes: string[];
};

export type TargetPersona = {
  id: string;
  full_name: string;
  job_title: string;
  location: string | null;
  linkedin: string | null;
  work_email: string | null;
  avatar_url: string | null;
  phone_number: string | null;
  company_name: string | null;
  current_time: string | null;
  time_current_position: string;
};

export type ChannelAttribution = {
  city: string;
  channel: string;
  platform: string;
  referrer: string;
  inserted_at: string;
  country_code: string;
};

export type SessionAnalytics = {
  id: string;
  sessions: number;
  updated_at: string;
  inserted_at: string;
  bucket_start_at: string;
  icp_fit_sessions: number;
  unique_companies: number;
  new_icp_fit_leads: number;
  identified_sessions: number;
  unique_new_companies: number;
};
