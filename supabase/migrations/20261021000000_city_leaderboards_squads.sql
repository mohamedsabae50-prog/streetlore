ALTER TABLE public.leaderboard
  ADD COLUMN IF NOT EXISTS current_streak integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS longest_streak integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_visit_days integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_visit_date timestamptz;

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
      checkins.user_id,
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
    GROUP BY checkins.user_id
  ),
  ranked AS (
    SELECT
      leaderboard.user_id,
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
      ON checkin_rollup.user_id = leaderboard.user_id
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

CREATE TABLE IF NOT EXISTS public.squads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  join_code text NOT NULL UNIQUE
    CHECK (join_code ~ '^[0-9]{6}$'),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours')
);

CREATE TABLE IF NOT EXISTS public.squad_members (
  squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  left_at timestamptz,
  PRIMARY KEY (squad_id, user_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_squad_members_one_active_per_user
  ON public.squad_members(user_id)
  WHERE left_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_squad_members_active_squad
  ON public.squad_members(squad_id)
  WHERE left_at IS NULL;

ALTER TABLE public.squads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.squad_members ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.squads, public.squad_members FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.squads, public.squad_members TO service_role;

CREATE OR REPLACE FUNCTION public.create_squad()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_squad public.squads%ROWTYPE;
  v_code text;
  v_attempt integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.squad_members AS members
  SET left_at = now()
  FROM public.squads AS squads
  WHERE members.squad_id = squads.id
    AND members.user_id = v_user_id
    AND members.left_at IS NULL
    AND (
      squads.status <> 'active'
      OR squads.expires_at <= now()
    );

  IF EXISTS (
    SELECT 1
    FROM public.squad_members AS members
    JOIN public.squads AS squads ON squads.id = members.squad_id
    WHERE members.user_id = v_user_id
      AND members.left_at IS NULL
      AND squads.status = 'active'
      AND squads.expires_at > now()
  ) THEN
    RAISE EXCEPTION 'Leave your current squad before creating another';
  END IF;

  FOR v_attempt IN 1..20 LOOP
    v_code := lpad(floor(random() * 1000000)::integer::text, 6, '0');
    BEGIN
      INSERT INTO public.squads (join_code, created_by)
      VALUES (v_code, v_user_id)
      RETURNING * INTO v_squad;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_squad := NULL;
    END;
  END LOOP;

  IF v_squad.id IS NULL THEN
    RAISE EXCEPTION 'Could not allocate a squad code; try again';
  END IF;

  INSERT INTO public.squad_members (squad_id, user_id)
  VALUES (v_squad.id, v_user_id);

  RETURN jsonb_build_object(
    'id', v_squad.id,
    'join_code', v_squad.join_code,
    'created_by', v_squad.created_by,
    'member_count', 1,
    'expires_at', v_squad.expires_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.join_squad(p_join_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_code text := btrim(coalesce(p_join_code, ''));
  v_squad public.squads%ROWTYPE;
  v_existing_squad_id uuid;
  v_member_count integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF v_code !~ '^[0-9]{4,6}$' THEN
    RAISE EXCEPTION 'Enter a valid 4-6 digit squad code';
  END IF;

  UPDATE public.squad_members AS members
  SET left_at = now()
  FROM public.squads AS squads
  WHERE members.squad_id = squads.id
    AND members.user_id = v_user_id
    AND members.left_at IS NULL
    AND (
      squads.status <> 'active'
      OR squads.expires_at <= now()
    );

  SELECT squads.id
  INTO v_existing_squad_id
  FROM public.squad_members AS members
  JOIN public.squads AS squads ON squads.id = members.squad_id
  WHERE members.user_id = v_user_id
    AND members.left_at IS NULL
    AND squads.status = 'active'
    AND squads.expires_at > now()
  LIMIT 1;

  SELECT *
  INTO v_squad
  FROM public.squads AS squads
  WHERE squads.join_code = v_code
    AND squads.status = 'active'
    AND squads.expires_at > now()
  FOR UPDATE;

  IF v_squad.id IS NULL THEN
    RAISE EXCEPTION 'Squad code is invalid or expired';
  END IF;
  IF v_existing_squad_id IS NOT NULL
     AND v_existing_squad_id <> v_squad.id THEN
    RAISE EXCEPTION 'Leave your current squad before joining another';
  END IF;

  INSERT INTO public.squad_members (squad_id, user_id)
  VALUES (v_squad.id, v_user_id)
  ON CONFLICT (squad_id, user_id)
  DO UPDATE SET left_at = NULL, joined_at = now();

  SELECT count(*)::integer
  INTO v_member_count
  FROM public.squad_members AS members
  WHERE members.squad_id = v_squad.id
    AND members.left_at IS NULL;

  RETURN jsonb_build_object(
    'id', v_squad.id,
    'join_code', v_squad.join_code,
    'created_by', v_squad.created_by,
    'member_count', v_member_count,
    'expires_at', v_squad.expires_at
  );
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'Leave your current squad before joining another';
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_active_squad()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_squad public.squads%ROWTYPE;
  v_member_count integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT squads.*
  INTO v_squad
  FROM public.squad_members AS members
  JOIN public.squads AS squads ON squads.id = members.squad_id
  WHERE members.user_id = v_user_id
    AND members.left_at IS NULL
    AND squads.status = 'active'
    AND squads.expires_at > now()
  ORDER BY members.joined_at DESC
  LIMIT 1;

  IF v_squad.id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT count(*)::integer
  INTO v_member_count
  FROM public.squad_members AS members
  WHERE members.squad_id = v_squad.id
    AND members.left_at IS NULL;

  RETURN jsonb_build_object(
    'id', v_squad.id,
    'join_code', v_squad.join_code,
    'created_by', v_squad.created_by,
    'member_count', v_member_count,
    'expires_at', v_squad.expires_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.leave_squad()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.squad_members
  SET left_at = now()
  WHERE user_id = auth.uid()
    AND left_at IS NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.create_squad() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.join_squad(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_my_active_squad() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.leave_squad() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_squad() TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_squad(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_active_squad() TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_squad() TO authenticated;
