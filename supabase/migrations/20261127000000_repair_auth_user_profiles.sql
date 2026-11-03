ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS created_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_lower_unique
  ON public.profiles (lower(username))
  WHERE username IS NOT NULL;

CREATE INDEX IF NOT EXISTS profiles_created_at_desc_idx
  ON public.profiles (created_at DESC);

CREATE OR REPLACE FUNCTION public.sync_auth_user_profile(
  p_user_id uuid,
  p_email text,
  p_created_at timestamptz,
  p_user_metadata jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_metadata jsonb := coalesce(p_user_metadata, '{}'::jsonb);
  v_username text := nullif(btrim(v_metadata ->> 'username'), '');
  v_display_name text := coalesce(
    nullif(btrim(v_metadata ->> 'display_name'), ''),
    nullif(btrim(v_metadata ->> 'full_name'), ''),
    nullif(btrim(v_metadata ->> 'name'), ''),
    nullif(btrim(split_part(coalesce(p_email, ''), '@', 1)), ''),
    'Explorer'
  );
BEGIN
  BEGIN
    INSERT INTO public.profiles (
      user_id,
      created_at,
      username,
      display_name
    )
    VALUES (
      p_user_id,
      p_created_at,
      v_username,
      v_display_name
    )
    ON CONFLICT (user_id) DO UPDATE
    SET created_at = coalesce(public.profiles.created_at, EXCLUDED.created_at),
        username = CASE
          WHEN nullif(btrim(public.profiles.username), '') IS NULL
            THEN EXCLUDED.username
          ELSE public.profiles.username
        END,
        display_name = CASE
          WHEN nullif(btrim(public.profiles.display_name), '') IS NULL
            OR lower(btrim(public.profiles.display_name)) = 'explorer'
            THEN EXCLUDED.display_name
          ELSE public.profiles.display_name
        END,
        updated_at = now();
  EXCEPTION WHEN unique_violation THEN
    INSERT INTO public.profiles (
      user_id,
      created_at,
      display_name
    )
    VALUES (
      p_user_id,
      p_created_at,
      v_display_name
    )
    ON CONFLICT (user_id) DO UPDATE
    SET created_at = coalesce(public.profiles.created_at, EXCLUDED.created_at),
        display_name = CASE
          WHEN nullif(btrim(public.profiles.display_name), '') IS NULL
            OR lower(btrim(public.profiles.display_name)) = 'explorer'
            THEN EXCLUDED.display_name
          ELSE public.profiles.display_name
        END,
        updated_at = now();
  END;
END;
$function$;

REVOKE ALL ON FUNCTION public.sync_auth_user_profile(
  uuid,
  text,
  timestamptz,
  jsonb
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  PERFORM public.sync_auth_user_profile(
    NEW.id,
    NEW.email,
    NEW.created_at,
    NEW.raw_user_meta_data
  );
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.handle_new_user()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_auth_user_created_profile ON auth.users;
DROP TRIGGER IF EXISTS streetlore_sync_profile_display_name ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_profile_sync ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

DO $block$
DECLARE
  v_user record;
BEGIN
  FOR v_user IN
    SELECT id, email, created_at, raw_user_meta_data
    FROM auth.users
    ORDER BY created_at
  LOOP
    PERFORM public.sync_auth_user_profile(
      v_user.id,
      v_user.email,
      v_user.created_at,
      v_user.raw_user_meta_data
    );
  END LOOP;
END;
$block$;

ALTER TABLE public.profiles
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN created_at SET NOT NULL;

GRANT SELECT ON TABLE public.profiles TO authenticated;
