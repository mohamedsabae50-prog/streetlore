-- Subscription integrity:
--   1. accept the 'annual' tier (the paywall sells PackageType.annual);
--   2. Pro expires server-side: the AI quota only treats a profile as Pro while
--      is_pro is true AND subscription_end_date is NULL (lifetime / legacy) or
--      still in the future, so a missed EXPIRATION webhook cannot leave Pro on
--      forever. Admin set_plan (weekly +7d, monthly +30d, annual +365d) and
--      lifetime (NULL) already store compatible end dates.
-- Idempotent: safe to re-run.

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_subscription_tier_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_subscription_tier_check
  CHECK (
    subscription_tier IS NULL OR
    subscription_tier IN ('weekly', 'monthly', 'annual', 'lifetime', 'free')
  );

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
  SELECT CASE
    WHEN COALESCE(profile.is_pro, false)
      AND (
        profile.subscription_end_date IS NULL
        OR profile.subscription_end_date > clock_timestamp()
      )
    THEN 50
    ELSE 3
  END
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

-- Keep the limit shown to the app identical to the one enforced above.
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

  SELECT CASE
    WHEN COALESCE(profile.is_pro, false)
      AND (
        profile.subscription_end_date IS NULL
        OR profile.subscription_end_date > v_current_time
      )
    THEN 50
    ELSE 3
  END
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
