CREATE OR REPLACE FUNCTION public.admin_update_user_plan(
  p_user_id uuid,
  p_tier text,
  p_duration_days integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_tier text := lower(btrim(coalesce(p_tier, '')));
  v_is_pro boolean;
  v_duration_days integer;
  v_end_date timestamptz;
  v_result jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;

  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'A target user is required' USING ERRCODE = '22023';
  END IF;

  v_tier := CASE v_tier
    WHEN 'yearly' THEN 'annual'
    WHEN 'pro' THEN 'lifetime'
    ELSE v_tier
  END;

  IF v_tier NOT IN ('free', 'weekly', 'monthly', 'annual', 'lifetime') THEN
    RAISE EXCEPTION 'Unsupported subscription tier: %', p_tier
      USING ERRCODE = '22023';
  END IF;

  IF p_duration_days IS NOT NULL
     AND (p_duration_days < 1 OR p_duration_days > 36500) THEN
    RAISE EXCEPTION 'Duration must be between 1 and 36500 days'
      USING ERRCODE = '22023';
  END IF;

  v_is_pro := v_tier <> 'free';
  v_duration_days := coalesce(
    p_duration_days,
    CASE v_tier
      WHEN 'weekly' THEN 7
      WHEN 'monthly' THEN 30
      WHEN 'annual' THEN 365
      ELSE NULL
    END
  );
  v_end_date := CASE
    WHEN NOT v_is_pro OR v_tier = 'lifetime' THEN NULL
    ELSE now() + make_interval(days => v_duration_days)
  END;

  UPDATE public.profiles
  SET is_pro = v_is_pro,
      subscription_tier = v_tier,
      subscription_end_date = v_end_date,
      updated_at = now()
  WHERE user_id = p_user_id
  RETURNING jsonb_build_object(
    'user_id', user_id,
    'is_pro', is_pro,
    'subscription_tier', subscription_tier,
    'subscription_end_date', subscription_end_date
  )
  INTO v_result;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile for user % was not found', p_user_id
      USING ERRCODE = 'P0002';
  END IF;

  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_update_user_plan(uuid, text, integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_user_plan(uuid, text, integer)
  TO authenticated;
