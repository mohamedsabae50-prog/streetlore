GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

DO $$
DECLARE
  relation record;
BEGIN
  FOR relation IN
    SELECT c.oid, c.relname, c.relrowsecurity
    FROM pg_class AS c
    JOIN pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r', 'p')
  LOOP
    IF NOT relation.relrowsecurity THEN
      EXECUTE format(
        'ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY',
        'public',
        relation.relname
      );
    END IF;

    EXECUTE format(
      'REVOKE ALL ON TABLE %I.%I FROM PUBLIC, anon, authenticated, service_role',
      'public',
      relation.relname
    );
    EXECUTE format(
      'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE %I.%I TO authenticated',
      'public',
      relation.relname
    );
    EXECUTE format(
      'GRANT ALL PRIVILEGES ON TABLE %I.%I TO service_role',
      'public',
      relation.relname
    );
    EXECUTE format(
      'GRANT SELECT ON TABLE %I.%I TO anon',
      'public',
      relation.relname
    );
  END LOOP;
END;
$$;

ALTER VIEW public.tours_with_places SET (security_invoker = true);
ALTER VIEW public.ai_quota_today SET (security_invoker = true);

REVOKE ALL ON TABLE public.tours_with_places, public.ai_quota_today
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.tours_with_places
  TO anon, authenticated, service_role;
GRANT SELECT ON TABLE public.ai_quota_today
  TO authenticated, service_role;

REVOKE ALL ON ALL SEQUENCES IN SCHEMA public
  FROM PUBLIC, anon, authenticated, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public
  TO authenticated, service_role;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public
  TO anon, authenticated, service_role;

-- Default privileges cannot enable RLS; every future table migration must
-- enable RLS and create its policies before exposing the table through the API.
-- The Management API session is postgres and cannot alter supabase_admin defaults.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC, anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT SELECT ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT ALL PRIVILEGES ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC, anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON FUNCTIONS FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO service_role;
