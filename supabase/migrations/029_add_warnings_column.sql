-- Add warnings column for partial success scenarios
-- (e.g., app deployed to Intune but assignments/categories could not be applied)
ALTER TABLE packaging_jobs
ADD COLUMN IF NOT EXISTS warnings JSONB;

COMMENT ON COLUMN packaging_jobs.warnings IS 'Array of warning messages for partial success scenarios (e.g., assignment or category failures after successful deployment)';
