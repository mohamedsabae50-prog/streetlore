ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS display_name text,
  ADD COLUMN IF NOT EXISTS is_pro boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_flagged boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS report_count integer NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
END;
$$;

ALTER TABLE public.leaderboard
  ADD COLUMN IF NOT EXISTS avatar_url text,
  ADD COLUMN IF NOT EXISTS is_flagged boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS report_count integer NOT NULL DEFAULT 0;

ALTER TABLE public.content_reports
  ADD COLUMN IF NOT EXISTS target_avatar_url text;

CREATE OR REPLACE FUNCTION public.streetlore_sync_profile_display_name()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  metadata_name text := COALESCE(
    NULLIF(btrim(NEW.raw_user_meta_data ->> 'display_name'), ''),
    NULLIF(btrim(NEW.raw_user_meta_data ->> 'full_name'), ''),
    NULLIF(btrim(NEW.raw_user_meta_data ->> 'name'), '')
  );
BEGIN
  IF metadata_name IS NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.profiles (user_id, display_name)
  VALUES (NEW.id, metadata_name)
  ON CONFLICT (user_id) DO UPDATE
  SET display_name = EXCLUDED.display_name,
      updated_at = now()
  WHERE public.profiles.display_name IS NULL
     OR btrim(public.profiles.display_name) = ''
     OR lower(btrim(public.profiles.display_name)) = 'explorer';

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.streetlore_sync_profile_display_name()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS streetlore_sync_profile_display_name
  ON auth.users;
CREATE TRIGGER streetlore_sync_profile_display_name
  AFTER INSERT OR UPDATE OF raw_user_meta_data ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.streetlore_sync_profile_display_name();

ALTER TABLE public.content_reports
  DROP CONSTRAINT IF EXISTS content_reports_target_type_check;

ALTER TABLE public.content_reports
  ADD CONSTRAINT content_reports_target_type_check
  CHECK (target_type IN ('chat', 'review', 'user'));

CREATE INDEX IF NOT EXISTS content_reports_user_open_created_idx
  ON public.content_reports (target_id, created_at DESC)
  WHERE target_type = 'user' AND status = 'open';

CREATE OR REPLACE FUNCTION public.streetlore_apply_content_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NEW.target_type = 'chat' THEN
    UPDATE public.place_chat
    SET report_count = report_count + 1,
        is_flagged = true
    WHERE id::text = NEW.target_id;
  ELSIF NEW.target_type = 'review' THEN
    UPDATE public.reviews
    SET report_count = report_count + 1,
        is_flagged = true
    WHERE id::text = NEW.target_id;
  ELSE
    UPDATE public.profiles
    SET report_count = report_count + 1,
        is_flagged = true,
        updated_at = now()
    WHERE user_id::text = NEW.target_id;

    UPDATE public.leaderboard
    SET report_count = report_count + 1,
        is_flagged = true
    WHERE user_id::text = NEW.target_id;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS content_reports_apply_target
  ON public.content_reports;
CREATE TRIGGER content_reports_apply_target
  AFTER INSERT ON public.content_reports
  FOR EACH ROW EXECUTE FUNCTION public.streetlore_apply_content_report();

CREATE OR REPLACE FUNCTION public.admin_list_user_accounts()
RETURNS TABLE(
  user_id uuid,
  username text,
  avatar_url text,
  is_pro boolean,
  is_flagged boolean,
  report_count integer,
  open_report_count bigint,
  report_reason text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    user_account.id,
    COALESCE(
      NULLIF(btrim(profile.username), ''),
      NULLIF(btrim(profile.display_name), ''),
      NULLIF(btrim(user_account.raw_user_meta_data ->> 'full_name'), ''),
      NULLIF(btrim(user_account.raw_user_meta_data ->> 'name'), ''),
      NULLIF(btrim(split_part(user_account.email, '@', 1)), ''),
      'Explorer'
    ),
    COALESCE(
      NULLIF(btrim(profile.avatar_url), ''),
      NULLIF(user_account.raw_user_meta_data ->> 'avatar_url', ''),
      NULLIF(user_account.raw_user_meta_data ->> 'picture', ''),
      NULLIF(user_account.raw_user_meta_data ->> 'photo_url', ''),
      NULLIF(board.avatar_url, '')
    ),
    COALESCE(profile.is_pro, false),
    COALESCE(profile.is_flagged, false) OR COALESCE(board.is_flagged, false),
    greatest(
      COALESCE(profile.report_count, 0),
      COALESCE(board.report_count, 0)
    ),
    COALESCE(reports.open_count, 0),
    reports.latest_reason
  FROM auth.users AS user_account
  LEFT JOIN public.profiles AS profile ON profile.user_id = user_account.id
  LEFT JOIN public.leaderboard AS board
    ON board.user_id::text = user_account.id::text
  LEFT JOIN LATERAL (
    SELECT
      count(*) AS open_count,
      (
        SELECT open_report.reason
        FROM public.content_reports AS open_report
        WHERE open_report.target_type = 'user'
          AND open_report.target_id = user_account.id::text
          AND open_report.status = 'open'
        ORDER BY open_report.created_at DESC
        LIMIT 1
      ) AS latest_reason
    FROM public.content_reports AS account_report
    WHERE account_report.target_type = 'user'
      AND account_report.target_id = user_account.id::text
      AND account_report.status = 'open'
  ) AS reports ON true
  ORDER BY
    (COALESCE(profile.is_flagged, false)
      OR COALESCE(board.is_flagged, false)
      OR COALESCE(reports.open_count, 0) > 0) DESC,
    COALESCE(reports.open_count, 0) DESC,
    greatest(
      COALESCE(profile.report_count, 0),
      COALESCE(board.report_count, 0)
    ) DESC,
    profile.updated_at DESC NULLS LAST;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_list_user_accounts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_user_accounts() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_dismiss_user_reports(
  target_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'Invalid account target' USING ERRCODE = '22023';
  END IF;

  UPDATE public.content_reports
  SET status = 'dismissed'
  WHERE target_type = 'user'
    AND target_id = target_user_id::text
    AND status = 'open';

  UPDATE public.profiles
  SET is_flagged = false,
      updated_at = now()
  WHERE user_id = target_user_id;

  UPDATE public.leaderboard
  SET is_flagged = false
  WHERE user_id::text = target_user_id::text;

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_dismiss_user_reports(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_dismiss_user_reports(uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.streetlore_is_protected_admin_user(
  target_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM auth.users AS user_account
    WHERE user_account.id = target_user_id
      AND (
        lower(btrim(coalesce(user_account.email, ''))) IN (
          'mohamedsabae50@gmail.com',
          'hackty65@gmail.com'
        )
        OR EXISTS (
          SELECT 1
          FROM public.admin_users AS admin
          WHERE admin.user_id = target_user_id
        )
        OR EXISTS (
          SELECT 1
          FROM public.profiles AS admin_profile
          WHERE admin_profile.user_id = target_user_id
            AND admin_profile.is_admin IS TRUE
        )
      )
  );
$function$;

REVOKE ALL ON FUNCTION public.streetlore_is_protected_admin_user(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_remove_user_avatar(
  target_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;
  IF target_user_id IS NULL OR target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Invalid account target' USING ERRCODE = '22023';
  END IF;
  IF public.streetlore_is_protected_admin_user(target_user_id) THEN
    RAISE EXCEPTION 'Cannot modify an admin account'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.profiles
  SET avatar_url = NULL,
      updated_at = now()
  WHERE user_id = target_user_id;

  UPDATE public.leaderboard
  SET avatar_url = NULL
  WHERE user_id::text = target_user_id::text;

  UPDATE public.place_chat
  SET avatar_url = NULL
  WHERE user_id::text = target_user_id::text;

  UPDATE auth.users
  SET raw_user_meta_data =
    COALESCE(raw_user_meta_data, '{}'::jsonb)
      - 'avatar_url'
      - 'picture'
      - 'photo_url'
  WHERE id = target_user_id;

  UPDATE public.content_reports
  SET status = 'resolved'
  WHERE target_type = 'user'
    AND target_id = target_user_id::text
    AND target_avatar_url IS NOT NULL
    AND btrim(target_avatar_url) <> ''
    AND status = 'open';

  UPDATE public.profiles AS profile
  SET is_flagged = EXISTS (
    SELECT 1
    FROM public.content_reports AS report
    WHERE report.target_type = 'user'
      AND report.target_id = target_user_id::text
      AND report.status = 'open'
  ),
  updated_at = now()
  WHERE profile.user_id = target_user_id;

  UPDATE public.leaderboard AS board
  SET is_flagged = EXISTS (
    SELECT 1
    FROM public.content_reports AS report
    WHERE report.target_type = 'user'
      AND report.target_id = target_user_id::text
      AND report.status = 'open'
  )
  WHERE board.user_id::text = target_user_id::text;

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_remove_user_avatar(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_remove_user_avatar(uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_reset_user_name(
  target_user_id uuid,
  new_name text DEFAULT 'Explorer'
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  clean_name text := left(NULLIF(btrim(new_name), ''), 40);
  unique_name text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;
  IF target_user_id IS NULL OR target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Invalid account target' USING ERRCODE = '22023';
  END IF;
  IF public.streetlore_is_protected_admin_user(target_user_id) THEN
    RAISE EXCEPTION 'Cannot modify an admin account'
      USING ERRCODE = '42501';
  END IF;

  clean_name := COALESCE(clean_name, 'Explorer');
  unique_name := clean_name;
  IF EXISTS (
    SELECT 1
    FROM public.profiles AS other_profile
    WHERE other_profile.user_id <> target_user_id
      AND lower(other_profile.username) = lower(clean_name)
  ) THEN
    unique_name := left(clean_name, 30) || '_' ||
      left(replace(target_user_id::text, '-', ''), 8);
  END IF;

  UPDATE public.profiles
  SET username = unique_name,
      display_name = clean_name,
      updated_at = now()
  WHERE user_id = target_user_id;

  UPDATE public.leaderboard
  SET user_name = clean_name
  WHERE user_id::text = target_user_id::text;

  UPDATE public.place_chat
  SET user_name = clean_name
  WHERE user_id::text = target_user_id::text;

  UPDATE auth.users
  SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object(
      'display_name', clean_name,
      'full_name', clean_name,
      'name', clean_name
    )
  WHERE id = target_user_id;

  RETURN FOUND;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_reset_user_name(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_reset_user_name(uuid, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_user_pro(
  target_user_id uuid,
  pro_enabled boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;
  IF target_user_id IS NULL OR pro_enabled IS NULL
     OR target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Invalid account update' USING ERRCODE = '22023';
  END IF;
  IF public.streetlore_is_protected_admin_user(target_user_id) THEN
    RAISE EXCEPTION 'Cannot modify an admin account'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.profiles
  SET is_pro = pro_enabled,
      subscription_tier = CASE WHEN pro_enabled THEN 'lifetime' ELSE 'free' END,
      subscription_end_date = NULL,
      updated_at = now()
  WHERE user_id = target_user_id;

  RETURN FOUND;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_set_user_pro(uuid, boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_user_pro(uuid, boolean)
  TO authenticated;
