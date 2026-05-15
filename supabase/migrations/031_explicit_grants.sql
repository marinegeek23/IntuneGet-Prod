-- Explicit GRANT statements required by Supabase's May 2026 Data API change.
-- From October 30, 2026 all projects must have explicit grants for PostgREST
-- (supabase-js, /rest/v1/) to access tables. Previously the default schema
-- grant covered this; that default is being removed.
--
-- Pattern:
--   anon        → SELECT on publicly readable tables (no auth required)
--   authenticated → full DML on all tables (RLS policies enforce row-level access)
--   service_role  → all on everything (used by GitHub Actions / server-side)

-- ============================================================================
-- curated_apps (public catalog, read by anyone)
-- ============================================================================
GRANT SELECT ON public.curated_apps TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.curated_apps TO authenticated;
GRANT ALL ON public.curated_apps TO service_role;

-- ============================================================================
-- curated_sync_status (public read)
-- ============================================================================
GRANT SELECT ON public.curated_sync_status TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.curated_sync_status TO authenticated;
GRANT ALL ON public.curated_sync_status TO service_role;

-- ============================================================================
-- version_history (public read)
-- ============================================================================
GRANT SELECT ON public.version_history TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.version_history TO authenticated;
GRANT ALL ON public.version_history TO service_role;

-- ============================================================================
-- installation_snapshots (public read)
-- ============================================================================
GRANT SELECT ON public.installation_snapshots TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.installation_snapshots TO authenticated;
GRANT ALL ON public.installation_snapshots TO service_role;

-- ============================================================================
-- packaging_jobs (authenticated only — owns their own rows via RLS)
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.packaging_jobs TO authenticated;
GRANT ALL ON public.packaging_jobs TO service_role;

-- ============================================================================
-- winget_packages (authenticated read/write, service all)
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.winget_packages TO authenticated;
GRANT ALL ON public.winget_packages TO service_role;

-- ============================================================================
-- winget_sync_status
-- ============================================================================
GRANT SELECT ON public.winget_sync_status TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.winget_sync_status TO authenticated;
GRANT ALL ON public.winget_sync_status TO service_role;

-- ============================================================================
-- upload_history
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.upload_history TO authenticated;
GRANT ALL ON public.upload_history TO service_role;

-- ============================================================================
-- update_check_results
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.update_check_results TO authenticated;
GRANT ALL ON public.update_check_results TO service_role;

-- ============================================================================
-- app_update_policies
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_update_policies TO authenticated;
GRANT ALL ON public.app_update_policies TO service_role;

-- ============================================================================
-- auto_update_history
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.auto_update_history TO authenticated;
GRANT ALL ON public.auto_update_history TO service_role;

-- ============================================================================
-- notification_preferences / notification_history
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_preferences TO authenticated;
GRANT ALL ON public.notification_preferences TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_history TO authenticated;
GRANT ALL ON public.notification_history TO service_role;

-- ============================================================================
-- user_settings
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_settings TO authenticated;
GRANT ALL ON public.user_settings TO service_role;

-- ============================================================================
-- tenant_consent
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tenant_consent TO authenticated;
GRANT ALL ON public.tenant_consent TO service_role;

-- ============================================================================
-- webhook_configurations
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.webhook_configurations TO authenticated;
GRANT ALL ON public.webhook_configurations TO service_role;

-- ============================================================================
-- SCCM tables
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sccm_apps TO authenticated;
GRANT ALL ON public.sccm_apps TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.sccm_migrations TO authenticated;
GRANT ALL ON public.sccm_migrations TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.sccm_migration_history TO authenticated;
GRANT ALL ON public.sccm_migration_history TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.sccm_winget_mappings TO authenticated;
GRANT ALL ON public.sccm_winget_mappings TO service_role;

-- ============================================================================
-- MSP tables
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.msp_organizations TO authenticated;
GRANT ALL ON public.msp_organizations TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.msp_managed_tenants TO authenticated;
GRANT ALL ON public.msp_managed_tenants TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.msp_user_memberships TO authenticated;
GRANT ALL ON public.msp_user_memberships TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.msp_batch_deployments TO authenticated;
GRANT ALL ON public.msp_batch_deployments TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.msp_batch_deployment_items TO authenticated;
GRANT ALL ON public.msp_batch_deployment_items TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.msp_webhook_configurations TO authenticated;
GRANT ALL ON public.msp_webhook_configurations TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.msp_webhook_deliveries TO authenticated;
GRANT ALL ON public.msp_webhook_deliveries TO service_role;

-- ============================================================================
-- Sequences (needed for INSERT on SERIAL columns)
-- ============================================================================
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- ============================================================================
-- Functions (EXECUTE needed for RPC calls via supabase-js)
-- Wrapped in DO block so missing functions don't abort the whole migration.
-- ============================================================================
DO $$
DECLARE
  func TEXT;
  funcs TEXT[] := ARRAY[
    'search_curated_apps(TEXT, TEXT, INTEGER)',
    'get_popular_curated_apps(INTEGER, TEXT)',
    'get_installation_changelog(TEXT, TEXT)',
    'get_version_history(TEXT, INTEGER)',
    'get_curated_categories()'
  ];
BEGIN
  FOREACH func IN ARRAY funcs LOOP
    BEGIN
      EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO anon, authenticated, service_role', func);
    EXCEPTION WHEN undefined_function THEN
      RAISE NOTICE 'Skipping GRANT for % (function does not exist)', func;
    END;
  END LOOP;
END $$;
