CREATE TABLE IF NOT EXISTS public.profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  is_pro boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users can read own profile" ON public.profiles;
CREATE POLICY "users can read own profile"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

REVOKE INSERT, UPDATE, DELETE ON public.profiles FROM anon, authenticated;
GRANT SELECT ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;

CREATE OR REPLACE FUNCTION public.create_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_profile ON auth.users;
CREATE TRIGGER on_auth_user_created_profile
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.create_user_profile();

INSERT INTO public.profiles (user_id)
SELECT id FROM auth.users
ON CONFLICT (user_id) DO NOTHING;

ALTER TABLE public.ai_quota
  ALTER COLUMN daily_limit SET DEFAULT 3;

UPDATE public.ai_quota
SET daily_limit = 3
WHERE daily_limit IS DISTINCT FROM 3;

ALTER TABLE public.tours
  ADD COLUMN IF NOT EXISTS is_premium boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_hidden_gem boolean NOT NULL DEFAULT false;

DROP FUNCTION IF EXISTS public.consume_ai_quota(text, integer);

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
  window_expired boolean;
BEGIN
  SELECT CASE WHEN COALESCE(profile.is_pro, false) THEN 50 ELSE 3 END
  INTO quota_limit
  FROM (SELECT 1) AS seed
  LEFT JOIN public.profiles AS profile
    ON profile.user_id::text = p_user_id;

  INSERT INTO public.ai_quota (user_id, daily_limit, used_today, window_start)
  VALUES (p_user_id, quota_limit, 0, now())
  ON CONFLICT (user_id) DO NOTHING;

  SELECT *
  INTO quota_row
  FROM public.ai_quota
  WHERE user_id = p_user_id
  FOR UPDATE;

  window_expired := quota_row.window_start <= now() - interval '24 hours';
  next_count := CASE WHEN window_expired THEN 1 ELSE quota_row.used_today + 1 END;

  IF next_count > quota_limit THEN
    UPDATE public.ai_quota
    SET daily_limit = quota_limit,
        updated_at = now()
    WHERE user_id = p_user_id;
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

REVOKE ALL ON FUNCTION public.consume_ai_quota(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_ai_quota(text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_ai_quota(text) TO service_role;

CREATE OR REPLACE VIEW public.tours_with_places AS
SELECT
  t.id,
  t.title,
  t.title_ar,
  t.description,
  t.description_ar,
  t.duration,
  t.duration_ar,
  t.category,
  t.category_ar,
  t.image_url,
  t.created_at,
  t.updated_at,
  COALESCE(
    (
      SELECT json_agg(
        json_build_object(
          'id', p.id,
          'name', p.name,
          'description', p.description,
          'imageUrl', p.image_url,
          'image_urls', p.image_urls,
          'rating', p.rating,
          'category', p.category,
          'lat', p.lat,
          'lng', p.lng,
          'address', p.address,
          'openHours', p.open_hours,
          'reviewCount', p.review_count,
          'priceLevel', p.price_level,
          'priceNote', p.price_note,
          'priceLocalEgp', p.price_local_egp,
          'priceForeignerEgp', p.price_foreigner_egp,
          'isHiddenGem', p.is_hidden_gem,
          'isFeatured', p.is_featured
        )
        ORDER BY tp.position
      )
      FROM public.tour_places tp
      JOIN public.places p ON p.id = tp.place_id
      WHERE tp.tour_id = t.id
    ),
    '[]'::json
  ) AS places,
  t.status,
  t.view_count,
  t.is_premium,
  t.is_hidden_gem
FROM public.tours t;
