-- Automatically reward approved Hidden Gems and support the monthly
-- leaderboard reward. Safe to apply repeatedly.

ALTER TABLE public.suggested_places
  ADD COLUMN IF NOT EXISTS reward_granted boolean NOT NULL DEFAULT false;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_subscription_tier_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_subscription_tier_check
  CHECK (
    subscription_tier IS NULL OR
    subscription_tier IN (
      'weekly', 'monthly', 'annual', 'lifetime', 'free', 'monthly_reward'
    )
  );

CREATE OR REPLACE FUNCTION public.grant_hidden_gem_reward()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NEW.status = 'approved'
     AND OLD.status IS DISTINCT FROM 'approved'
     AND NEW.reward_granted = false
     AND NEW.user_id IS NOT NULL THEN
    UPDATE public.profiles
       SET is_pro = true,
           subscription_tier = COALESCE(
             NULLIF(subscription_tier, 'free'),
             'monthly_reward'
           ),
           subscription_end_date =
             GREATEST(COALESCE(subscription_end_date, now()), now())
             + interval '30 days',
           updated_at = now()
     WHERE user_id = NEW.user_id;

    IF FOUND THEN
      NEW.reward_granted := true;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS suggested_places_grant_pro_reward
  ON public.suggested_places;
CREATE TRIGGER suggested_places_grant_pro_reward
  BEFORE UPDATE OF status ON public.suggested_places
  FOR EACH ROW
  EXECUTE FUNCTION public.grant_hidden_gem_reward();

CREATE OR REPLACE FUNCTION public.grant_monthly_top_visitor_reward(
  target_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF auth.uid() IS NULL
     OR lower(coalesce(auth.jwt() ->> 'email', '')) <>
        lower('mohamedsabae50@gmail.com') THEN
    RAISE EXCEPTION 'Only an administrator can grant monthly rewards'
      USING ERRCODE = '42501';
  END IF;

  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'A target user is required'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.profiles
     SET is_pro = true,
         subscription_tier = COALESCE(
           NULLIF(subscription_tier, 'free'),
           'monthly_reward'
         ),
         subscription_end_date =
           GREATEST(COALESCE(subscription_end_date, now()), now())
           + interval '30 days',
         updated_at = now()
   WHERE user_id = target_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile for user % was not found', target_user_id
      USING ERRCODE = 'P0002';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.grant_hidden_gem_reward() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.grant_monthly_top_visitor_reward(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.grant_monthly_top_visitor_reward(uuid)
  TO authenticated;
