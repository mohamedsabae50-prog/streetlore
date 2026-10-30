BEGIN;

DROP TRIGGER IF EXISTS place_checkins_sync_leaderboard_count
  ON public.place_checkins;

ALTER TABLE public.place_checkins
  ALTER COLUMN place_id TYPE text USING place_id::text,
  ALTER COLUMN checked_in_at SET DEFAULT now();

UPDATE public.place_checkins
SET checked_in_at = now()
WHERE checked_in_at IS NULL;

ALTER TABLE public.place_checkins
  ALTER COLUMN checked_in_at SET NOT NULL;

DO $$
DECLARE
  place_id_fk record;
BEGIN
  FOR place_id_fk IN
    SELECT constraint_row.conname
    FROM pg_constraint AS constraint_row
    JOIN pg_attribute AS attribute_row
      ON attribute_row.attrelid = constraint_row.conrelid
     AND attribute_row.attnum = ANY(constraint_row.conkey)
    WHERE constraint_row.conrelid = 'public.place_checkins'::regclass
      AND constraint_row.contype = 'f'
      AND attribute_row.attname = 'place_id'
  LOOP
    EXECUTE format(
      'ALTER TABLE public.place_checkins DROP CONSTRAINT %I',
      place_id_fk.conname
    );
  END LOOP;
END;
$$;

ALTER TABLE public.place_checkins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.place_checkins FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.place_checkins TO authenticated;

DROP POLICY IF EXISTS "users can manage own place checkins"
  ON public.place_checkins;
DROP POLICY IF EXISTS "users can read own and shared friend checkins"
  ON public.place_checkins;
DROP POLICY IF EXISTS "users can select own and shared place checkins"
  ON public.place_checkins;
DROP POLICY IF EXISTS "users can insert own place checkins"
  ON public.place_checkins;
DROP POLICY IF EXISTS "users can update own place checkins"
  ON public.place_checkins;
DROP POLICY IF EXISTS "users can delete own place checkins"
  ON public.place_checkins;

CREATE POLICY "users can select own and shared place checkins"
  ON public.place_checkins
  FOR SELECT
  TO authenticated
  USING (public.can_view_user_activity(user_id::text));

CREATE POLICY "users can insert own place checkins"
  ON public.place_checkins
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "users can update own place checkins"
  ON public.place_checkins
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "users can delete own place checkins"
  ON public.place_checkins
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.sync_leaderboard_place_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  affected_user_id uuid;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    affected_user_id := OLD.user_id;
    IF affected_user_id IS NOT NULL THEN
      INSERT INTO public.leaderboard (user_id, user_name, places_visited)
      SELECT
        affected_user_id::text,
        COALESCE(
          NULLIF(btrim(profile.display_name), ''),
          NULLIF(btrim(profile.username), ''),
          'Explorer'
        ),
        (
          SELECT count(DISTINCT checkin.place_id)::integer
          FROM public.place_checkins AS checkin
          WHERE checkin.user_id = affected_user_id
        )
      FROM public.profiles AS profile
      WHERE profile.user_id = affected_user_id
      UNION ALL
      SELECT
        affected_user_id::text,
        'Explorer',
        (
          SELECT count(DISTINCT checkin.place_id)::integer
          FROM public.place_checkins AS checkin
          WHERE checkin.user_id = affected_user_id
        )
      WHERE NOT EXISTS (
        SELECT 1
        FROM public.profiles AS profile
        WHERE profile.user_id = affected_user_id
      )
      ON CONFLICT (user_id) DO UPDATE
      SET places_visited = EXCLUDED.places_visited;
    END IF;
  END IF;

  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    affected_user_id := NEW.user_id;
    IF affected_user_id IS NOT NULL
      AND (TG_OP = 'INSERT' OR affected_user_id IS DISTINCT FROM OLD.user_id)
    THEN
      INSERT INTO public.leaderboard (user_id, user_name, places_visited)
      SELECT
        affected_user_id::text,
        COALESCE(
          NULLIF(btrim(profile.display_name), ''),
          NULLIF(btrim(profile.username), ''),
          'Explorer'
        ),
        (
          SELECT count(DISTINCT checkin.place_id)::integer
          FROM public.place_checkins AS checkin
          WHERE checkin.user_id = affected_user_id
        )
      FROM public.profiles AS profile
      WHERE profile.user_id = affected_user_id
      UNION ALL
      SELECT
        affected_user_id::text,
        'Explorer',
        (
          SELECT count(DISTINCT checkin.place_id)::integer
          FROM public.place_checkins AS checkin
          WHERE checkin.user_id = affected_user_id
        )
      WHERE NOT EXISTS (
        SELECT 1
        FROM public.profiles AS profile
        WHERE profile.user_id = affected_user_id
      )
      ON CONFLICT (user_id) DO UPDATE
      SET places_visited = EXCLUDED.places_visited;
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS place_checkins_sync_leaderboard_count
  ON public.place_checkins;
CREATE TRIGGER place_checkins_sync_leaderboard_count
  AFTER INSERT OR UPDATE OF user_id, place_id OR DELETE
  ON public.place_checkins
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_leaderboard_place_count();

INSERT INTO public.leaderboard (user_id, user_name, places_visited)
SELECT
  checkin.user_id::text,
  COALESCE(
    NULLIF(btrim(profile.display_name), ''),
    NULLIF(btrim(profile.username), ''),
    'Explorer'
  ),
  count(DISTINCT checkin.place_id)::integer
FROM public.place_checkins AS checkin
LEFT JOIN public.profiles AS profile
  ON profile.user_id = checkin.user_id
WHERE checkin.user_id IS NOT NULL
GROUP BY checkin.user_id, profile.display_name, profile.username
ON CONFLICT (user_id) DO UPDATE
SET places_visited = EXCLUDED.places_visited;

UPDATE public.leaderboard AS leaderboard
SET places_visited = 0
WHERE NOT EXISTS (
  SELECT 1
  FROM public.place_checkins AS checkin
  WHERE checkin.user_id::text = leaderboard.user_id
);

CREATE OR REPLACE FUNCTION public.normalize_badge_array(p_badges jsonb)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $function$
  WITH expanded AS (
    SELECT
      badge.value,
      badge.ordinality::integer AS position,
      CASE
        WHEN jsonb_typeof(badge.value) = 'object'
          THEN badge.value ->> 'id'
        WHEN jsonb_typeof(badge.value) = 'string'
          THEN badge.value #>> '{}'
        ELSE NULL
      END AS raw_id,
      CASE
        WHEN COALESCE(badge.value ->> 'points_awarded', '') ~ '^[0-9]+$'
          THEN (badge.value ->> 'points_awarded')::integer
        ELSE 0
      END AS points_awarded
    FROM jsonb_array_elements(
      CASE
        WHEN jsonb_typeof(p_badges) = 'array' THEN p_badges
        ELSE '[]'::jsonb
      END
    ) WITH ORDINALITY AS badge(value, ordinality)
  ),
  mapped AS (
    SELECT
      expanded.value,
      expanded.position,
      expanded.raw_id,
      expanded.points_awarded,
      COALESCE(
        CASE expanded.raw_id
          WHEN 'first_steps' THEN 'first_step'
          WHEN 'b_checkin_first' THEN 'first_step'
          WHEN 'culture_vulture' THEN 'culture_buff'
          ELSE expanded.raw_id
        END,
        '__legacy_badge_' || expanded.position::text
      ) AS canonical_id
    FROM expanded
  ),
  normalized AS (
    SELECT
      mapped.position,
      mapped.points_awarded,
      mapped.canonical_id,
      CASE
        WHEN jsonb_typeof(mapped.value) = 'object' THEN
          jsonb_set(
            jsonb_set(
              jsonb_set(
                mapped.value,
                '{id}',
                to_jsonb(mapped.canonical_id),
                true
              ),
              '{name}',
              to_jsonb(
                CASE
                  WHEN mapped.raw_id IS DISTINCT FROM mapped.canonical_id
                    OR COALESCE(mapped.value ->> 'name', '') ~*
                      '^(badge|ach)_.+_name$'
                  THEN initcap(replace(mapped.canonical_id, '_', ' '))
                  ELSE COALESCE(mapped.value ->> 'name', 'Explorer Badge')
                END
              ),
              true
            ),
            '{description}',
            to_jsonb(
              CASE
                WHEN COALESCE(mapped.value ->> 'description', '') ~*
                  '^(badge|ach)_.+_desc$'
                THEN 'Earned while exploring the hidden stories of Egypt.'
                ELSE COALESCE(mapped.value ->> 'description', '')
              END
            ),
            true
          )
        WHEN jsonb_typeof(mapped.value) = 'string'
          THEN to_jsonb(mapped.canonical_id)
        ELSE mapped.value
      END AS badge
    FROM mapped
  ),
  deduplicated AS (
    SELECT DISTINCT ON (normalized.canonical_id)
      normalized.position,
      normalized.badge
    FROM normalized
    ORDER BY
      normalized.canonical_id,
      normalized.points_awarded DESC,
      normalized.position
  )
  SELECT COALESCE(
    jsonb_agg(deduplicated.badge ORDER BY deduplicated.position),
    '[]'::jsonb
  )
  FROM deduplicated;
$function$;

REVOKE ALL ON FUNCTION public.normalize_badge_array(jsonb)
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS leaderboard_notify_new_badges
  ON public.leaderboard;

UPDATE public.profiles
SET badges = public.normalize_badge_array(badges)
WHERE badges IS DISTINCT FROM public.normalize_badge_array(badges);

UPDATE public.leaderboard
SET badges = public.normalize_badge_array(badges)
WHERE badges IS DISTINCT FROM public.normalize_badge_array(badges);

CREATE TRIGGER leaderboard_notify_new_badges
  AFTER INSERT OR UPDATE OF badges
  ON public.leaderboard
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_new_badges();

DELETE FROM public.notifications AS older
USING public.notifications AS newer
WHERE older.type = 'badge_unlocked'
  AND newer.type = 'badge_unlocked'
  AND older.recipient_id = newer.recipient_id
  AND CASE older.metadata ->> 'badge_id'
    WHEN 'first_steps' THEN 'first_step'
    WHEN 'b_checkin_first' THEN 'first_step'
    WHEN 'culture_vulture' THEN 'culture_buff'
    ELSE older.metadata ->> 'badge_id'
  END
  = CASE newer.metadata ->> 'badge_id'
    WHEN 'first_steps' THEN 'first_step'
    WHEN 'b_checkin_first' THEN 'first_step'
    WHEN 'culture_vulture' THEN 'culture_buff'
    ELSE newer.metadata ->> 'badge_id'
  END
  AND (older.created_at, older.id) < (newer.created_at, newer.id);

UPDATE public.notifications AS notification
SET title = 'Badge unlocked',
    body = '',
    metadata = jsonb_set(
      jsonb_set(
        jsonb_set(
          notification.metadata,
          '{badge_id}',
          to_jsonb(
            CASE notification.metadata ->> 'badge_id'
              WHEN 'first_steps' THEN 'first_step'
              WHEN 'b_checkin_first' THEN 'first_step'
              WHEN 'culture_vulture' THEN 'culture_buff'
              ELSE COALESCE(
                notification.metadata ->> 'badge_id',
                'explorer'
              )
            END
          ),
          true
        ),
        '{badge_name}',
        to_jsonb(
          initcap(
            replace(
              CASE notification.metadata ->> 'badge_id'
                WHEN 'first_steps' THEN 'first_step'
                WHEN 'b_checkin_first' THEN 'first_step'
                WHEN 'culture_vulture' THEN 'culture_buff'
                ELSE COALESCE(
                  notification.metadata ->> 'badge_id',
                  'explorer'
                )
              END,
              '_',
              ' '
            )
          )
        ),
        true
      ),
      '{badge_description}',
      to_jsonb(
        'Earned while exploring the hidden stories of Egypt.'::text
      ),
      true
    )
WHERE COALESCE(notification.title, '') ~* '(badge|ach)_[a-z0-9_]+_(name|desc)'
   OR COALESCE(notification.body, '') ~* '(badge|ach)_[a-z0-9_]+_(name|desc)'
   OR COALESCE(notification.metadata::text, '') ~*
      '(badge|ach)_[a-z0-9_]+_(name|desc)';

CREATE TABLE IF NOT EXISTS public.user_blocked_users (
  blocker_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_user_id),
  CHECK (blocker_id <> blocked_user_id)
);

ALTER TABLE public.user_blocked_users ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_blocked_users FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.user_blocked_users TO authenticated;

DROP POLICY IF EXISTS "Users can manage their own blocked users"
  ON public.user_blocked_users;
CREATE POLICY "Users can manage their own blocked users"
  ON public.user_blocked_users
  FOR ALL
  TO authenticated
  USING (blocker_id = auth.uid())
  WITH CHECK (
    blocker_id = auth.uid()
    AND blocker_id <> blocked_user_id
  );

INSERT INTO public.user_blocked_users (blocker_id, blocked_user_id, created_at)
SELECT blocker_id, blocked_user_id, created_at
FROM public.blocked_users
ON CONFLICT (blocker_id, blocked_user_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.sync_user_blocked_users()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF pg_trigger_depth() > 1 THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'DELETE' THEN
    IF TG_TABLE_NAME = 'user_blocked_users' THEN
      DELETE FROM public.blocked_users
      WHERE blocker_id = OLD.blocker_id
        AND blocked_user_id = OLD.blocked_user_id;
    ELSE
      DELETE FROM public.user_blocked_users
      WHERE blocker_id = OLD.blocker_id
        AND blocked_user_id = OLD.blocked_user_id;
    END IF;
    RETURN OLD;
  END IF;

  IF TG_TABLE_NAME = 'user_blocked_users' THEN
    INSERT INTO public.blocked_users (blocker_id, blocked_user_id, created_at)
    VALUES (NEW.blocker_id, NEW.blocked_user_id, NEW.created_at)
    ON CONFLICT (blocker_id, blocked_user_id) DO NOTHING;
  ELSE
    INSERT INTO public.user_blocked_users
      (blocker_id, blocked_user_id, created_at)
    VALUES (NEW.blocker_id, NEW.blocked_user_id, NEW.created_at)
    ON CONFLICT (blocker_id, blocked_user_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.sync_user_blocked_users()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS user_blocked_users_sync_legacy
  ON public.user_blocked_users;
CREATE TRIGGER user_blocked_users_sync_legacy
  AFTER INSERT OR DELETE ON public.user_blocked_users
  FOR EACH ROW EXECUTE FUNCTION public.sync_user_blocked_users();

DROP TRIGGER IF EXISTS blocked_users_sync_current
  ON public.blocked_users;
CREATE TRIGGER blocked_users_sync_current
  AFTER INSERT OR DELETE ON public.blocked_users
  FOR EACH ROW EXECUTE FUNCTION public.sync_user_blocked_users();

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  account_id uuid := auth.uid();
BEGIN
  IF account_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required'
      USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.leaderboard
  WHERE user_id = account_id::text;

  DELETE FROM auth.users
  WHERE id = account_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Account deletion did not remove the authenticated user';
  END IF;

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.delete_my_account()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account()
  TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
