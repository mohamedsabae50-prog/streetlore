BEGIN;

SELECT set_config('request.jwt.claim.role', 'service_role', true);
SELECT set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);

DO $test$
DECLARE
  v_user_id uuid;
  v_place_id text;
  v_added jsonb;
  v_removed jsonb;
  v_is_visited boolean;
  v_points integer;
  v_profile_xp integer;
  v_badges jsonb;
  v_profile_badges jsonb;
BEGIN
  SELECT account.id
  INTO v_user_id
  FROM auth.users AS account
  JOIN public.profiles AS profile ON profile.user_id = account.id
  WHERE lower(COALESCE(account.email, '')) NOT IN (
    'mohamedsabae50@gmail.com',
    'hackty65@gmail.com'
  )
  ORDER BY account.created_at, account.id
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No non-admin test account is available';
  END IF;

  SELECT place.id
  INTO v_place_id
  FROM public.places AS place
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.place_checkins AS checkin
    WHERE checkin.user_id = v_user_id
      AND checkin.place_id = place.id::text
  )
  ORDER BY place.id
  LIMIT 1;

  IF v_place_id IS NULL THEN
    RAISE EXCEPTION 'No unvisited place is available for the smoke test';
  END IF;

  v_added := public.admin_manage_user_visits(
    v_user_id,
    ARRAY[v_place_id],
    'add'
  );
  IF (v_added->>'added_count')::integer <> 1 THEN
    RAISE EXCEPTION 'Add smoke test did not insert exactly one visit: %',
      v_added;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.place_checkins AS checkin
    WHERE checkin.user_id = v_user_id
      AND checkin.place_id = v_place_id
  )
  INTO v_is_visited;
  IF NOT v_is_visited THEN
    RAISE EXCEPTION 'Added check-in was not visible inside the transaction';
  END IF;

  SELECT leaderboard.total_points, leaderboard.badges,
         profile.xp, profile.badges
  INTO v_points, v_badges, v_profile_xp, v_profile_badges
  FROM public.leaderboard AS leaderboard
  JOIN public.profiles AS profile
    ON profile.user_id::text = leaderboard.user_id
  WHERE leaderboard.user_id = v_user_id::text;

  IF v_points IS DISTINCT FROM v_profile_xp
    OR v_badges IS DISTINCT FROM v_profile_badges
  THEN
    RAISE EXCEPTION 'Add did not synchronize leaderboard/profile XP and badges';
  END IF;

  v_removed := public.admin_manage_user_visits(
    v_user_id,
    ARRAY[v_place_id],
    'remove'
  );
  IF (v_removed->>'removed_count')::integer <> 1 THEN
    RAISE EXCEPTION 'Remove smoke test did not delete exactly one visit: %',
      v_removed;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.place_checkins AS checkin
    WHERE checkin.user_id = v_user_id
      AND checkin.place_id = v_place_id
  ) THEN
    RAISE EXCEPTION 'Removed check-in still exists inside the transaction';
  END IF;

  SELECT leaderboard.total_points, leaderboard.badges,
         profile.xp, profile.badges
  INTO v_points, v_badges, v_profile_xp, v_profile_badges
  FROM public.leaderboard AS leaderboard
  JOIN public.profiles AS profile
    ON profile.user_id::text = leaderboard.user_id
  WHERE leaderboard.user_id = v_user_id::text;

  IF v_points IS DISTINCT FROM v_profile_xp
    OR v_badges IS DISTINCT FROM v_profile_badges
  THEN
    RAISE EXCEPTION 'Remove did not synchronize leaderboard/profile XP and badges';
  END IF;
END;
$test$;

ROLLBACK;

SELECT 'add/remove transactional smoke test passed' AS result;
