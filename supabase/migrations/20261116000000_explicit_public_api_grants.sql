GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

ALTER TABLE public.saved_places ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policy
    WHERE polrelid = 'public.saved_places'::regclass
      AND polname = 'auth read own saved_places'
  ) THEN
    EXECUTE 'CREATE POLICY "auth read own saved_places"
      ON public.saved_places
      FOR SELECT
      TO authenticated
      USING (auth.uid()::text = user_id)';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policy
    WHERE polrelid = 'public.saved_places'::regclass
      AND polname = 'auth upsert own saved_places'
  ) THEN
    EXECUTE 'CREATE POLICY "auth upsert own saved_places"
      ON public.saved_places
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid()::text = user_id)';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policy
    WHERE polrelid = 'public.saved_places'::regclass
      AND polname = 'auth update own saved_places'
  ) THEN
    EXECUTE 'CREATE POLICY "auth update own saved_places"
      ON public.saved_places
      FOR UPDATE
      TO authenticated
      USING (auth.uid()::text = user_id)
      WITH CHECK (auth.uid()::text = user_id)';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policy
    WHERE polrelid = 'public.saved_places'::regclass
      AND polname = 'auth delete own saved_places'
  ) THEN
    EXECUTE 'CREATE POLICY "auth delete own saved_places"
      ON public.saved_places
      FOR DELETE
      TO authenticated
      USING (auth.uid()::text = user_id)';
  END IF;
END;
$$;

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
    EXECUTE format(
      'REVOKE ALL ON TABLE %I.%I FROM PUBLIC, anon',
      'public',
      relation.relname
    );

    EXECUTE format(
      'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE %I.%I TO authenticated, service_role',
      'public',
      relation.relname
    );

    IF relation.relrowsecurity THEN
      EXECUTE format(
        'GRANT SELECT ON TABLE %I.%I TO anon',
        'public',
        relation.relname
      );
    END IF;
  END LOOP;
END;
$$;

REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public
  TO authenticated, service_role;

DO $$
DECLARE
  routine record;
BEGIN
  FOR routine IN
    SELECT p.oid
    FROM pg_proc AS p
    JOIN pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind IN ('f', 'p')
  LOOP
    EXECUTE format(
      'GRANT EXECUTE ON ROUTINE %s TO service_role',
      routine.oid::regprocedure
    );

    IF has_function_privilege('anon', routine.oid, 'EXECUTE') THEN
      EXECUTE format(
        'GRANT EXECUTE ON ROUTINE %s TO anon',
        routine.oid::regprocedure
      );
    END IF;

    IF has_function_privilege('authenticated', routine.oid, 'EXECUTE') THEN
      EXECUTE format(
        'GRANT EXECUTE ON ROUTINE %s TO authenticated',
        routine.oid::regprocedure
      );
    END IF;
  END LOOP;
END;
$$;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC, anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT SELECT ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC, anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO anon;
