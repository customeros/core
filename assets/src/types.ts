export type Stage = 'target' | 'education' | 'solution' | 'evaluation' | 'readyToBuy';

export type Lead = {
  id: string;
  icon: string;
  name: string;
  stage: Stage;
  count: number;
  domain: string;
  country: string;
  industry: string;
  document_id: string;
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
  group?: 'stage' | 'industry' | 'country';
  asc?: 'inserted_at' | 'name' | 'industry' | 'stage' | 'country';
  desc?: 'inserted_at' | 'name' | 'industry' | 'stage' | 'country';
};

export type IcpProfile = {
  profile: string;
  qualifying_attributes: string[];
};
