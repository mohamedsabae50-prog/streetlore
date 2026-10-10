-- Enforce a maximum of 15 AI proxy requests per rolling 24-hour window.
-- The security-definer RPC performs the check and increment atomically.

ALTER TABLE public.ai_quota
  ALTER COLUMN daily_limit SET DEFAULT 15;

UPDATE public.ai_quota
SET daily_limit = LEAST(daily_limit, 15)
WHERE daily_limit > 15;

CREATE OR REPLACE FUNCTION public.consume_ai_quota(
  p_user_id text,
  p_daily_limit integer
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  quota_row public.ai_quota%ROWTYPE;
  quota_limit integer;
  next_count integer;
  window_expired boolean;
BEGIN
  INSERT INTO public.ai_quota (user_id, daily_limit, used_today, window_start)
  VALUES (p_user_id, LEAST(p_daily_limit, 15), 0, now())
  ON CONFLICT (user_id) DO NOTHING;

  SELECT *
  INTO quota_row
  FROM public.ai_quota
  WHERE user_id = p_user_id
  FOR UPDATE;

  quota_limit := LEAST(quota_row.daily_limit, p_daily_limit, 15);
  window_expired := quota_row.window_start <= now() - interval '24 hours';
  next_count := CASE WHEN window_expired THEN 1 ELSE quota_row.used_today + 1 END;

  IF next_count > quota_limit THEN
    RETURN false;
  END IF;

  UPDATE public.ai_quota
  SET daily_limit = quota_limit,
      used_today = next_count,
      window_start = CASE WHEN window_expired THEN now() ELSE window_start END,
      updated_at = now()
  WHERE user_id = p_user_id;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.consume_ai_quota(text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_ai_quota(text, integer) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_ai_quota(text, integer) TO service_role;
