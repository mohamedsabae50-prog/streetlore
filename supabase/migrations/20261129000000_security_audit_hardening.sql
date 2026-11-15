BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS ai_daily_count integer NOT NULL DEFAULT 0;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.leaderboard ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE
  ON TABLE public.profiles
  FROM PUBLIC, anon, authenticated;

DO $block$
DECLARE
  profile_column record;
BEGIN
  FOR profile_column IN
    SELECT attribute.attname
    FROM pg_attribute AS attribute
    WHERE attribute.attrelid = 'public.profiles'::regclass
      AND attribute.attnum > 0
      AND NOT attribute.attisdropped
  LOOP
    EXECUTE format(
      'REVOKE INSERT (%1$I), UPDATE (%1$I) ON TABLE public.profiles FROM PUBLIC, anon, authenticated',
      profile_column.attname
    );
  END LOOP;
END;
$block$;

GRANT INSERT (user_id, username, updated_at, avatar_url)
  ON TABLE public.profiles TO authenticated;
GRANT UPDATE (username, updated_at, avatar_url, share_location_activity)
  ON TABLE public.profiles TO authenticated;

CREATE OR REPLACE FUNCTION public.protect_profile_sensitive_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  IF current_setting('role', true) IS DISTINCT FROM 'service_role'
     AND NOT public.is_admin()
  THEN
    IF TG_OP = 'INSERT' THEN
      NEW.is_admin := false;
      NEW.is_pro := false;
      NEW.subscription_tier := NULL;
      NEW.subscription_end_date := NULL;
      NEW.ai_daily_count := 0;
    ELSE
      NEW.is_admin := OLD.is_admin;
      NEW.is_pro := OLD.is_pro;
      NEW.subscription_tier := OLD.subscription_tier;
      NEW.subscription_end_date := OLD.subscription_end_date;
      NEW.ai_daily_count := OLD.ai_daily_count;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.protect_profile_sensitive_columns()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS protect_profile_admin_flag_insert
  ON public.profiles;
DROP TRIGGER IF EXISTS protect_profile_admin_flag_update
  ON public.profiles;
DROP TRIGGER IF EXISTS protect_profile_sensitive_columns
  ON public.profiles;
CREATE TRIGGER protect_profile_sensitive_columns
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_profile_sensitive_columns();

REVOKE INSERT, UPDATE, DELETE
  ON TABLE public.leaderboard
  FROM PUBLIC, anon;
REVOKE DELETE ON TABLE public.leaderboard FROM authenticated;
GRANT INSERT, UPDATE ON TABLE public.leaderboard TO authenticated;

DO $block$
DECLARE
  write_policy record;
BEGIN
  FOR write_policy IN
    SELECT policy.policyname
    FROM pg_policies AS policy
    WHERE policy.schemaname = 'public'
      AND policy.tablename = 'leaderboard'
      AND policy.cmd IN ('ALL', 'INSERT', 'UPDATE', 'DELETE')
  LOOP
    EXECUTE format(
      'DROP POLICY %I ON public.leaderboard',
      write_policy.policyname
    );
  END LOOP;
END;
$block$;

CREATE POLICY "authenticated insert own leaderboard row"
  ON public.leaderboard
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id::text = auth.uid()::text OR public.is_admin());
CREATE POLICY "authenticated update own leaderboard row"
  ON public.leaderboard
  FOR UPDATE
  TO authenticated
  USING (user_id::text = auth.uid()::text OR public.is_admin())
  WITH CHECK (user_id::text = auth.uid()::text OR public.is_admin());

CREATE OR REPLACE FUNCTION public.protect_leaderboard_writes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  request_role text := current_setting('role', true);
  current_user_id text := auth.uid()::text;
  actual_places bigint;
BEGIN
  IF request_role = 'anon' THEN
    RAISE EXCEPTION 'Anonymous leaderboard writes are not allowed'
      USING ERRCODE = '42501';
  END IF;

  IF request_role IS DISTINCT FROM 'authenticated'
     OR public.is_admin()
  THEN
    RETURN NEW;
  END IF;

  IF current_user_id IS NULL
     OR NEW.user_id::text IS DISTINCT FROM current_user_id
  THEN
    RAISE EXCEPTION 'Users may only write their own leaderboard row'
      USING ERRCODE = '42501';
  END IF;

  IF to_regclass('public.user_visits') IS NOT NULL THEN
    EXECUTE
      'SELECT count(DISTINCT visit.place_id)::bigint
         FROM (
           SELECT place_id::text AS place_id
             FROM public.user_visits
            WHERE user_id::text = $1
           UNION
           SELECT place_id::text
             FROM public.place_checkins
            WHERE user_id::text = $1
         ) AS visit'
      INTO actual_places
      USING current_user_id;
  ELSE
    SELECT count(DISTINCT checkin.place_id)::bigint
      INTO actual_places
      FROM public.place_checkins AS checkin
     WHERE checkin.user_id::text = current_user_id;
  END IF;

  IF NEW.places_visited IS NULL
     OR NEW.places_visited < 0
     OR NEW.places_visited > actual_places
     OR NEW.places_visited > 100000
  THEN
    RAISE EXCEPTION 'places_visited exceeds verified place activity'
      USING ERRCODE = '22023';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.protect_leaderboard_writes()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS protect_leaderboard_writes
  ON public.leaderboard;
CREATE TRIGGER protect_leaderboard_writes
  BEFORE INSERT OR UPDATE ON public.leaderboard
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_leaderboard_writes();

ALTER TABLE public.place_checkins ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.protect_place_checkin_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  request_role text := current_setting('role', true);
  authenticated_user_id uuid := auth.uid();
BEGIN
  IF request_role = 'authenticated' AND NOT public.is_admin() THEN
    IF authenticated_user_id IS NULL THEN
      RAISE EXCEPTION 'Authentication required'
        USING ERRCODE = '42501';
    END IF;
    NEW.user_id := authenticated_user_id;

    PERFORM pg_advisory_xact_lock(
      hashtextextended(NEW.user_id::text || ':' || NEW.place_id::text, 0)
    );
    IF EXISTS (
      SELECT 1
        FROM public.place_checkins AS existing
       WHERE existing.user_id = NEW.user_id
         AND existing.place_id = NEW.place_id
         AND existing.checked_in_at >= now() - interval '1 hour'
    ) THEN
      RAISE EXCEPTION 'A check-in for this place was recorded within the last hour'
        USING ERRCODE = '23505';
    END IF;
  ELSIF request_role = 'anon' THEN
    RAISE EXCEPTION 'Authentication required'
      USING ERRCODE = '42501';
  END IF;

  NEW.checked_in_at := now();
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.protect_place_checkin_insert()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS protect_place_checkin_insert
  ON public.place_checkins;
CREATE TRIGGER protect_place_checkin_insert
  BEFORE INSERT ON public.place_checkins
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_place_checkin_insert();

CREATE OR REPLACE FUNCTION public.record_verified_place_checkin(
  p_place_id text,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  authenticated_user_id uuid := auth.uid();
  place_coordinates record;
  distance_meters double precision;
BEGIN
  IF authenticated_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required'
      USING ERRCODE = '42501';
  END IF;
  IF NULLIF(btrim(p_place_id), '') IS NULL THEN
    RAISE EXCEPTION 'p_place_id is required'
      USING ERRCODE = '22023';
  END IF;
  IF (p_lat IS NULL) IS DISTINCT FROM (p_lng IS NULL) THEN
    RAISE EXCEPTION 'Both latitude and longitude must be provided together'
      USING ERRCODE = '22023';
  END IF;
  IF p_lat IS NOT NULL
     AND (p_lat NOT BETWEEN -90 AND 90 OR p_lng NOT BETWEEN -180 AND 180)
  THEN
    RAISE EXCEPTION 'Coordinates are outside valid latitude/longitude bounds'
      USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(authenticated_user_id::text || ':' || p_place_id, 0)
  );

  IF p_lat IS NOT NULL THEN
    SELECT place.lat::double precision AS lat,
           place.lng::double precision AS lng
      INTO place_coordinates
      FROM public.places AS place
     WHERE place.id::text = p_place_id;

    IF FOUND THEN
      distance_meters := 2 * 6371000 * asin(
        sqrt(
          least(
            1.0,
            power(sin(radians(p_lat - place_coordinates.lat) / 2), 2)
            + cos(radians(place_coordinates.lat))
              * cos(radians(p_lat))
              * power(sin(radians(p_lng - place_coordinates.lng) / 2), 2)
          )
        )
      );
      IF distance_meters > 300 THEN
        RAISE EXCEPTION 'Check-in location is more than 300 meters from the place'
          USING ERRCODE = '22023';
      END IF;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1
      FROM public.place_checkins AS existing
     WHERE existing.user_id = authenticated_user_id
       AND existing.place_id = p_place_id
       AND existing.checked_in_at >= now() - interval '1 hour'
  ) THEN
    RAISE EXCEPTION 'A check-in for this place was recorded within the last hour'
      USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.place_checkins (user_id, place_id, checked_in_at)
  VALUES (authenticated_user_id, p_place_id, now());
END;
$function$;

REVOKE ALL ON FUNCTION public.record_verified_place_checkin(
  text, double precision, double precision
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_verified_place_checkin(
  text, double precision, double precision
) TO authenticated;

REVOKE INSERT ON TABLE public.place_checkins
  FROM PUBLIC, anon, authenticated;

ALTER TABLE public.tours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tour_places ENABLE ROW LEVEL SECURITY;

DO $block$
DECLARE
  write_policy record;
  target_table text;
BEGIN
  FOREACH target_table IN ARRAY ARRAY['tours', 'tour_places']
  LOOP
    FOR write_policy IN
      SELECT policy.policyname
      FROM pg_policies AS policy
      WHERE policy.schemaname = 'public'
        AND policy.tablename = target_table
        AND policy.cmd IN ('ALL', 'INSERT', 'UPDATE', 'DELETE')
    LOOP
      EXECUTE format(
        'DROP POLICY %I ON public.%I',
        write_policy.policyname,
        target_table
      );
    END LOOP;
  END LOOP;
END;
$block$;

CREATE POLICY "admin can insert tours"
  ON public.tours
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());
CREATE POLICY "admin can update tours"
  ON public.tours
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
CREATE POLICY "admin can delete tours"
  ON public.tours
  FOR DELETE TO authenticated
  USING (public.is_admin());

CREATE POLICY "admin can insert tour_places"
  ON public.tour_places
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());
CREATE POLICY "admin can update tour_places"
  ON public.tour_places
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
CREATE POLICY "admin can delete tour_places"
  ON public.tour_places
  FOR DELETE TO authenticated
  USING (public.is_admin());

REVOKE INSERT, UPDATE, DELETE
  ON TABLE public.tours, public.tour_places
  FROM PUBLIC, anon;
GRANT INSERT, UPDATE, DELETE
  ON TABLE public.tours, public.tour_places TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
