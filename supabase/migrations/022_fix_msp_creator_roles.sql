-- Fix: Set role to 'owner' for all MSP organization creators
-- who were incorrectly assigned the default 'operator' role.
-- See: https://github.com/ugurkocde/IntuneGet/issues/53

-- Create msp_role type if it doesn't exist
DO $$ BEGIN
  CREATE TYPE msp_role AS ENUM ('owner', 'admin', 'operator', 'viewer');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Add role column if it doesn't exist
ALTER TABLE msp_user_memberships ADD COLUMN IF NOT EXISTS role msp_role NOT NULL DEFAULT 'viewer';

UPDATE msp_user_memberships m
SET role = 'owner'
FROM msp_organizations o
WHERE m.msp_organization_id = o.id
  AND m.user_id = o.created_by_user_id
  AND m.role != 'owner';

-- Change default role to 'viewer' (principle of least privilege).
ALTER TABLE msp_user_memberships ALTER COLUMN role SET DEFAULT 'viewer'::msp_role;
