INSERT INTO leads (
  id,
  tenant_id,
  ref_id,
  type,
  stage,
  icp_fit,
  inserted_at,
  updated_at
) VALUES
  ('lead-1', 'tenant_vba487vqg51yxffg', '1', 'company', 'target', 'strong', NOW(), NOW()),
  ('lead-2', 'tenant_vba487vqg51yxffg', '2', 'company', 'target', 'moderate', NOW(), NOW());