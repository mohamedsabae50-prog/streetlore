CREATE TABLE IF NOT EXISTS public.profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  is_pro boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS username text,
  ADD COLUMN IF NOT EXISTS is_pro boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_lower_unique
  ON public.profiles (lower(username))
  WHERE username IS NOT NULL;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users can read own profile" ON public.profiles;
CREATE POLICY "users can read own profile"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "authenticated can read public profile fields"
  ON public.profiles;
CREATE POLICY "authenticated can read public profile fields"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (true);
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

ALTER TABLE public.leaderboard
  ADD COLUMN IF NOT EXISTS current_streak integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS longest_streak integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_visit_days integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_visit_date timestamptz;

ALTER TABLE public.leaderboard ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "authenticated can read leaderboard"
  ON public.leaderboard;
CREATE POLICY "authenticated can read leaderboard"
  ON public.leaderboard
  FOR SELECT
  TO authenticated
  USING (true);

ALTER TABLE public.place_checkins ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "authenticated can read place checkins"
  ON public.place_checkins;
CREATE POLICY "authenticated can read place checkins"
  ON public.place_checkins
  FOR SELECT
  TO authenticated
  USING (true);

ALTER TABLE public.suggested_places ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "authenticated can read approved suggestions"
  ON public.suggested_places;
CREATE POLICY "authenticated can read approved suggestions"
  ON public.suggested_places
  FOR SELECT
  TO authenticated
  USING (status = 'approved');

CREATE OR REPLACE FUNCTION public.get_city_leaderboard(
  p_period text DEFAULT 'week',
  p_metric text DEFAULT 'check_ins',
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  user_id uuid,
  user_name text,
  avatar_color_hex text,
  total_points integer,
  places_visited integer,
  reviews_posted integer,
  photos_uploaded integer,
  level text,
  badges jsonb,
  current_streak integer,
  longest_streak integer,
  total_visit_days integer,
  last_visit_date timestamptz,
  check_ins bigint,
  hidden_gems bigint,
  score bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_since timestamptz;
BEGIN
  IF p_period NOT IN ('week', 'month', 'all_time') THEN
    RAISE EXCEPTION 'Unsupported leaderboard period';
  END IF;
  IF p_metric NOT IN ('check_ins', 'longest_streak', 'hidden_gems') THEN
    RAISE EXCEPTION 'Unsupported leaderboard metric';
  END IF;

  v_since := CASE p_period
    WHEN 'week' THEN
      date_trunc('week', statement_timestamp() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'
    WHEN 'month' THEN
      date_trunc('month', statement_timestamp() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'
    ELSE NULL
  END;

  RETURN QUERY
  WITH checkin_rollup AS (
    SELECT
      CAST(checkins.user_id AS uuid) AS user_id,
      count(*) FILTER (
        WHERE v_since IS NULL OR checkins.checked_in_at >= v_since
      ) AS check_ins,
      count(DISTINCT checkins.place_id) FILTER (
        WHERE places.is_hidden_gem IS TRUE
          AND (v_since IS NULL OR checkins.checked_in_at >= v_since)
      ) AS hidden_gems
    FROM public.place_checkins AS checkins
    LEFT JOIN public.places AS places
      ON places.id = checkins.place_id
    GROUP BY CAST(checkins.user_id AS uuid)
  ),
  ranked AS (
    SELECT
      CAST(leaderboard.user_id AS uuid) AS user_id,
      leaderboard.user_name,
      leaderboard.avatar_color_hex,
      leaderboard.total_points,
      leaderboard.places_visited,
      leaderboard.reviews_posted,
      leaderboard.photos_uploaded,
      leaderboard.level,
      coalesce(leaderboard.badges, '[]'::jsonb) AS badges,
      leaderboard.current_streak,
      leaderboard.longest_streak,
      leaderboard.total_visit_days,
      leaderboard.last_visit_date,
      coalesce(checkin_rollup.check_ins, 0) AS check_ins,
      coalesce(checkin_rollup.hidden_gems, 0) AS hidden_gems,
      CASE p_metric
        WHEN 'check_ins' THEN coalesce(checkin_rollup.check_ins, 0)
        WHEN 'longest_streak' THEN coalesce(leaderboard.longest_streak, 0)
        WHEN 'hidden_gems' THEN coalesce(checkin_rollup.hidden_gems, 0)
      END AS score
    FROM public.leaderboard AS leaderboard
    LEFT JOIN checkin_rollup
      ON checkin_rollup.user_id = CAST(leaderboard.user_id AS uuid)
  )
  SELECT
    ranked.user_id,
    ranked.user_name,
    ranked.avatar_color_hex,
    ranked.total_points,
    ranked.places_visited,
    ranked.reviews_posted,
    ranked.photos_uploaded,
    ranked.level,
    ranked.badges,
    ranked.current_streak,
    ranked.longest_streak,
    ranked.total_visit_days,
    ranked.last_visit_date,
    ranked.check_ins,
    ranked.hidden_gems,
    ranked.score
  FROM ranked
  ORDER BY ranked.score DESC, ranked.total_points DESC, ranked.user_name
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
END;
$$;

REVOKE ALL ON FUNCTION public.get_city_leaderboard(text, text, integer)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_city_leaderboard(text, text, integer)
  TO anon, authenticated;
