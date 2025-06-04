export type Lead = {
  id: string;
  icon: string;
  name: string;
  count: number;
  stage: string;
  country: string;
  country_name: string;
  domain: string;
  industry: string;
  document_id: string;
  icp_fit: 'strong' | 'moderate';
};

export type Tenant = {
  id: string;
  name: string;
  domain: string;
  inserted_at: string;
  updated_at: string;
  workspace_name: string;
  workspace_icon_key: string;
};

export type User = {
  id: string;
  email: string;
  tenant_id: string;
  updated_at: string;
  inserted_at: string;
  confirmed_at: string;
};
