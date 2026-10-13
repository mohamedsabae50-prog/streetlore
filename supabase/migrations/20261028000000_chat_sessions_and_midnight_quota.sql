ALTER TABLE public.ai_chat_logs
  ADD COLUMN IF NOT EXISTS session_id uuid;

CREATE INDEX IF NOT EXISTS ai_chat_logs_session_created_at_idx
  ON public.ai_chat_logs (session_id, created_at);

CREATE OR REPLACE FUNCTION public.consume_ai_quota(p_user_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  quota_row public.ai_quota%ROWTYPE;
  quota_limit integer;
  next_count integer;
  v_now timestamptz;
  v_today date;
  v_day_start timestamptz;
  window_expired boolean;
BEGIN
  SELECT CASE WHEN COALESCE(profile.is_pro, false) THEN 50 ELSE 3 END
  INTO quota_limit
  FROM (SELECT 1) AS seed
  LEFT JOIN public.profiles AS profile
    ON profile.user_id::text = p_user_id;

  v_now := clock_timestamp();
  v_today := (v_now AT TIME ZONE 'Africa/Cairo')::date;
  v_day_start := v_today::timestamp AT TIME ZONE 'Africa/Cairo';

  INSERT INTO public.ai_quota (user_id, daily_limit, used_today, window_start)
  VALUES (p_user_id, quota_limit, 0, v_day_start)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT *
  INTO quota_row
  FROM public.ai_quota
  WHERE user_id = p_user_id
  FOR UPDATE;

  v_now := clock_timestamp();
  v_today := (v_now AT TIME ZONE 'Africa/Cairo')::date;
  v_day_start := v_today::timestamp AT TIME ZONE 'Africa/Cairo';
  window_expired :=
    (quota_row.window_start AT TIME ZONE 'Africa/Cairo')::date
      IS DISTINCT FROM v_today;
  next_count := CASE
    WHEN window_expired THEN 1
    ELSE quota_row.used_today + 1
  END;

  IF next_count > quota_limit THEN
    UPDATE public.ai_quota
    SET daily_limit = quota_limit,
        updated_at = v_now
    WHERE user_id = p_user_id;
    RETURN false;
  END IF;

  UPDATE public.ai_quota
  SET daily_limit = quota_limit,
      used_today = next_count,
      window_start = CASE
        WHEN window_expired THEN v_day_start
        ELSE window_start
      END,
      updated_at = v_now
  WHERE user_id = p_user_id;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.consume_ai_quota(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_ai_quota(text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_ai_quota(text) TO service_role;

CREATE OR REPLACE VIEW public.ai_quota_today AS
SELECT
  user_id,
  daily_limit,
  CASE
    WHEN (window_start AT TIME ZONE 'Africa/Cairo')::date =
      (statement_timestamp() AT TIME ZONE 'Africa/Cairo')::date
      THEN used_today
    ELSE 0
  END AS used_today,
  CASE
    WHEN (window_start AT TIME ZONE 'Africa/Cairo')::date =
      (statement_timestamp() AT TIME ZONE 'Africa/Cairo')::date
      THEN GREATEST(daily_limit - used_today, 0)
    ELSE daily_limit
  END AS remaining,
  window_start,
  updated_at
FROM public.ai_quota;

GRANT SELECT ON public.ai_quota_today TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_ai_quota_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_id text;
  current_limit integer;
  current_used integer;
  v_current_time timestamptz := statement_timestamp();
  cairo_today date;
  cairo_day_start timestamptz;
  next_reset timestamptz;
BEGIN
  current_user_id := auth.uid()::text;
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required'
      USING ERRCODE = '42501';
  END IF;

  SELECT CASE WHEN COALESCE(profile.is_pro, false) THEN 50 ELSE 3 END
  INTO current_limit
  FROM (SELECT 1) AS seed
  LEFT JOIN public.profiles AS profile
    ON profile.user_id::text = current_user_id;

  cairo_today := (v_current_time AT TIME ZONE 'Africa/Cairo')::date;
  cairo_day_start := cairo_today::timestamp AT TIME ZONE 'Africa/Cairo';
  next_reset := (cairo_today + 1)::timestamp AT TIME ZONE 'Africa/Cairo';

  SELECT CASE
    WHEN (quota.window_start AT TIME ZONE 'Africa/Cairo')::date = cairo_today
      THEN quota.used_today
    ELSE 0
  END
  INTO current_used
  FROM public.ai_quota AS quota
  WHERE quota.user_id = current_user_id;

  current_used := COALESCE(current_used, 0);

  RETURN jsonb_build_object(
    'daily_limit', current_limit,
    'used_today', current_used,
    'remaining', GREATEST(current_limit - current_used, 0),
    'day_start', cairo_day_start,
    'next_reset_at', next_reset
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_ai_quota_status() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_my_ai_quota_status() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_my_ai_quota_status() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_admin_analytics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF lower(coalesce(auth.jwt() ->> 'email', '')) <>
     lower('mohamedsabae50@gmail.com') THEN
    RAISE EXCEPTION 'Admin access required'
      USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'total_ai_guide_usage',
    coalesce(
      (
        SELECT sum(used_today)
        FROM public.ai_quota
        WHERE (window_start AT TIME ZONE 'Africa/Cairo')::date =
          (statement_timestamp() AT TIME ZONE 'Africa/Cairo')::date
      ),
      0
    ),
    'total_checkins',
    (SELECT count(*) FROM public.place_checkins),
    'popular_tours',
    coalesce(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', popular.id,
            'title', popular.title,
            'view_count', popular.view_count
          )
          ORDER BY popular.view_count DESC, popular.title
        )
        FROM (
          SELECT id, title, view_count
          FROM public.tours
          WHERE status = 'published'
          ORDER BY view_count DESC, title
          LIMIT 5
        ) AS popular
      ),
      '[]'::jsonb
    ),
    'top_places_by_checkins',
    coalesce(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'place_id', popular.place_id,
            'place_name', popular.place_name,
            'checkin_count', popular.checkin_count
          )
          ORDER BY popular.checkin_count DESC, popular.place_name
        )
        FROM (
          SELECT
            checkins.place_id,
            coalesce(nullif(places.name, ''), checkins.place_id) AS place_name,
            count(*) AS checkin_count
          FROM public.place_checkins AS checkins
          LEFT JOIN public.places AS places
            ON places.id = checkins.place_id
          GROUP BY checkins.place_id, places.name
          ORDER BY count(*) DESC, place_name
          LIMIT 5
        ) AS popular
      ),
      '[]'::jsonb
    )
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_admin_analytics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_analytics() TO authenticated;
