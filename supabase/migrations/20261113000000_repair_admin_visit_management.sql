CREATE OR REPLACE FUNCTION public.admin_manage_user_visits(
  target_user_id uuid,
  place_ids text[],
  operation text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_added integer := 0;
  v_removed integer := 0;
  v_old_visit_count integer := 0;
  v_visit_count integer := 0;
  v_historical integer := 0;
  v_culture integer := 0;
  v_food integer := 0;
  v_nature integer := 0;
  v_shopping integer := 0;
  v_mosques integer := 0;
  v_churches integer := 0;
  v_hidden_gems integer := 0;
  v_completed_tours integer := 0;
  v_accepted_friends integer := 0;
  v_old_points integer := 0;
  v_total_points integer := 0;
  v_old_badges jsonb := '[]'::jsonb;
  v_preserved_badges jsonb := '[]'::jsonb;
  v_visit_badges jsonb := '[]'::jsonb;
  v_badges jsonb := '[]'::jsonb;
  v_newly_unlocked jsonb := '[]'::jsonb;
  v_old_badge_points integer := 0;
  v_new_badge_points integer := 0;
  v_visit_badge_points integer := 0;
  v_user_name text;
  v_visit_badge_ids text[] := ARRAY[
    'first_steps', 'street_explorer', 'lore_master', 'alexandria_legend',
    'explorer_5', 'explorer_10', 'explorer_25', 'lorekeeper',
    'time_traveler', 'culture_vulture', 'culture_buff', 'history_nerd',
    'alex_foodie', 'foodie', 'gourmet', 'nature_lover', 'shopaholic',
    'spiritual_seeker', 'pilgrim', 'hidden_gem_hunter', 'early_bird',
    'night_owl', 'completionist', 'social_explorer'
  ];
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Admin service role is required'
      USING ERRCODE = '42501';
  END IF;
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'target_user_id is required'
      USING ERRCODE = '22023';
  END IF;
  IF operation IS NULL OR operation NOT IN ('add', 'remove') THEN
    RAISE EXCEPTION 'Unsupported visit operation'
      USING ERRCODE = '22023';
  END IF;
  IF place_ids IS NULL
    OR cardinality(place_ids) = 0
    OR cardinality(place_ids) > 100
    OR EXISTS (
      SELECT 1
      FROM unnest(place_ids) AS requested(place_id)
      WHERE NULLIF(btrim(requested.place_id), '') IS NULL
         OR NOT EXISTS (
           SELECT 1
           FROM public.places AS place
           WHERE place.id::text = btrim(requested.place_id)
         )
    )
  THEN
    RAISE EXCEPTION 'Invalid place_ids'
      USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(NULLIF(profile.username, ''), 'Explorer')
  INTO v_user_name
  FROM public.profiles AS profile
  WHERE profile.user_id = target_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Target profile not found'
      USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.leaderboard (user_id, user_name)
  VALUES (target_user_id::text, v_user_name)
  ON CONFLICT (user_id) DO NOTHING;

  PERFORM 1
  FROM public.leaderboard AS leaderboard
  WHERE leaderboard.user_id = target_user_id::text
  FOR UPDATE;

  SELECT count(*)::integer
  INTO v_old_visit_count
  FROM public.place_checkins AS checkin
  WHERE checkin.user_id = target_user_id;

  IF operation = 'add' THEN
    INSERT INTO public.place_checkins (user_id, place_id, checked_in_at)
    SELECT target_user_id, requested.place_id, statement_timestamp()
    FROM (
      SELECT DISTINCT btrim(unnest(place_ids)) AS place_id
    ) AS requested
    ON CONFLICT (user_id, place_id) DO NOTHING;
    GET DIAGNOSTICS v_added = ROW_COUNT;
  ELSE
    DELETE FROM public.place_checkins AS checkin
    WHERE checkin.user_id = target_user_id
      AND checkin.place_id = ANY(place_ids);
    GET DIAGNOSTICS v_removed = ROW_COUNT;
  END IF;

  SELECT
    count(*)::integer,
    count(*) FILTER (WHERE place.category = 'Historical')::integer,
    count(*) FILTER (WHERE place.category = 'Culture')::integer,
    count(*) FILTER (WHERE place.category = 'Food')::integer,
    count(*) FILTER (WHERE place.category = 'Nature')::integer,
    count(*) FILTER (WHERE place.category = 'Shopping')::integer,
    count(*) FILTER (WHERE place.category = 'Mosques')::integer,
    count(*) FILTER (WHERE place.category = 'Churches')::integer,
    count(*) FILTER (WHERE place.is_hidden_gem IS TRUE)::integer
  INTO
    v_visit_count, v_historical, v_culture, v_food, v_nature,
    v_shopping, v_mosques, v_churches, v_hidden_gems
  FROM public.place_checkins AS checkin
  JOIN public.places AS place
    ON place.id::text = checkin.place_id
  WHERE checkin.user_id = target_user_id;

  SELECT count(*)::integer
  INTO v_completed_tours
  FROM public.tours AS tour
  WHERE EXISTS (
    SELECT 1
    FROM public.tour_places AS tour_place
    WHERE tour_place.tour_id = tour.id
  )
    AND NOT EXISTS (
      SELECT 1
      FROM public.tour_places AS tour_place
      WHERE tour_place.tour_id = tour.id
        AND NOT EXISTS (
          SELECT 1
          FROM public.place_checkins AS checkin
          WHERE checkin.user_id = target_user_id
            AND checkin.place_id = tour_place.place_id::text
        )
    );

  SELECT count(*)::integer
  INTO v_accepted_friends
  FROM public.friendships AS friendship
  WHERE friendship.status = 'accepted'
    AND target_user_id IN (friendship.requester_id, friendship.recipient_id);

  SELECT
    CASE
      WHEN jsonb_typeof(leaderboard.badges) = 'array'
        THEN leaderboard.badges
      ELSE '[]'::jsonb
    END,
    COALESCE(leaderboard.total_points, 0)
  INTO v_old_badges, v_old_points
  FROM public.leaderboard AS leaderboard
  WHERE leaderboard.user_id = target_user_id::text;

  SELECT
    COALESCE(
      jsonb_agg(old_badge.value)
        FILTER (WHERE NOT (old_badge.value->>'id' = ANY(v_visit_badge_ids))),
      '[]'::jsonb
    ),
    COALESCE(
      sum(COALESCE((old_badge.value->>'points_awarded')::integer, 0))
        FILTER (WHERE old_badge.value->>'id' = ANY(v_visit_badge_ids)),
      0
    )::integer
  INTO v_preserved_badges, v_old_badge_points
  FROM jsonb_array_elements(v_old_badges) AS old_badge(value);

  SELECT
    result.visit_badges,
    result.newly_unlocked,
    result.visit_badge_points,
    result.new_badge_points
  INTO v_visit_badges, v_newly_unlocked,
       v_visit_badge_points, v_new_badge_points
  FROM (
    WITH definitions AS (
      SELECT *
      FROM (VALUES
      ('first_steps', 'ach_first_steps_name', 'ach_first_steps_desc', 'flag_rounded', 'bronze', 50, v_visit_count >= 1),
      ('street_explorer', 'ach_street_explorer_name', 'ach_street_explorer_desc', 'explore_rounded', 'bronze', 100, v_visit_count >= 5),
      ('lore_master', 'ach_lore_master_name', 'ach_lore_master_desc', 'auto_stories_rounded', 'silver', 250, v_visit_count >= 15),
      ('alexandria_legend', 'ach_alexandria_legend_name', 'ach_alexandria_legend_desc', 'workspace_premium_rounded', 'gold', 500, v_visit_count >= 30),
      ('explorer_5', 'ach_explorer_5_name', 'ach_explorer_5_desc', 'explore_rounded', 'bronze', 25, v_visit_count >= 5),
      ('explorer_10', 'ach_explorer_10_name', 'ach_explorer_10_desc', 'travel_explore_rounded', 'silver', 50, v_visit_count >= 10),
      ('explorer_25', 'ach_explorer_25_name', 'ach_explorer_25_desc', 'public_rounded', 'gold', 100, v_visit_count >= 25),
      ('lorekeeper', 'ach_lorekeeper_name', 'ach_lorekeeper_desc', 'workspace_premium_rounded', 'platinum', 500, v_visit_count >= 42),
      ('time_traveler', 'ach_time_traveler_name', 'ach_time_traveler_desc', 'history_edu_rounded', 'bronze', 150, v_historical >= 5),
      ('culture_vulture', 'ach_culture_vulture_name', 'ach_culture_vulture_desc', 'museum_rounded', 'silver', 150, v_culture >= 5),
      ('culture_buff', 'ach_culture_buff_name', 'ach_culture_buff_desc', 'museum_rounded', 'silver', 40, v_historical + v_culture >= 5),
      ('history_nerd', 'ach_history_nerd_name', 'ach_history_nerd_desc', 'account_balance_rounded', 'gold', 80, v_historical + v_culture >= 10),
      ('alex_foodie', 'ach_alex_foodie_name', 'ach_alex_foodie_desc', 'restaurant_rounded', 'bronze', 120, v_food >= 4),
      ('foodie', 'ach_foodie_name', 'ach_foodie_desc', 'restaurant_rounded', 'bronze', 30, v_food >= 3),
      ('gourmet', 'ach_gourmet_name', 'ach_gourmet_desc', 'local_dining_rounded', 'gold', 75, v_food >= 8),
      ('nature_lover', 'ach_nature_lover_name', 'ach_nature_lover_desc', 'park_rounded', 'bronze', 100, v_nature >= 3),
      ('shopaholic', 'ach_shopaholic_name', 'ach_shopaholic_desc', 'shopping_bag_rounded', 'silver', 35, v_shopping >= 3),
      ('spiritual_seeker', 'ach_spiritual_seeker_name', 'ach_spiritual_seeker_desc', 'mosque_rounded', 'silver', 35, v_mosques >= 2),
      ('pilgrim', 'ach_pilgrim_name', 'ach_pilgrim_desc', 'church_rounded', 'gold', 50, v_churches >= 2),
      ('hidden_gem_hunter', 'ach_hidden_gem_hunter_name', 'ach_hidden_gem_hunter_desc', 'diamond_rounded', 'gold', 75, v_hidden_gems >= 3),
      ('early_bird', 'ach_early_bird_name', 'ach_early_bird_desc', 'wb_sunny_rounded', 'silver', 40, v_visit_count >= 5),
      ('night_owl', 'ach_night_owl_name', 'ach_night_owl_desc', 'nights_stay_rounded', 'silver', 40, v_visit_count >= 5),
      ('completionist', 'ach_completionist_name', 'ach_completionist_desc', 'check_circle_rounded', 'platinum', 500, v_completed_tours >= 20),
      ('social_explorer', 'ach_social_explorer_name', 'ach_social_explorer_desc', 'diversity_3_rounded', 'silver', 100, v_accepted_friends >= 3)
      ) AS badge(id, name, description, icon_name, tier, points, qualified)
    ),
    assembled AS (
      SELECT
        definition.id,
        jsonb_build_object(
          'id', definition.id,
          'name', definition.name,
          'description', definition.description,
          'icon_name', definition.icon_name,
          'tier', definition.tier,
          'earned_at', COALESCE(
            old_badge.value->>'earned_at',
            statement_timestamp()::text
          ),
          'points_awarded', definition.points
        ) AS badge,
        old_badge.value IS NULL AS is_new
      FROM definitions AS definition
      LEFT JOIN LATERAL (
        SELECT existing.value
        FROM jsonb_array_elements(v_old_badges) AS existing(value)
        WHERE existing.value->>'id' = definition.id
        LIMIT 1
      ) AS old_badge ON true
      WHERE definition.qualified
    )
    SELECT
      COALESCE(jsonb_agg(assembled.badge ORDER BY assembled.id), '[]'::jsonb)
        AS visit_badges,
      COALESCE(
        jsonb_agg(assembled.badge ORDER BY assembled.id)
          FILTER (WHERE assembled.is_new),
        '[]'::jsonb
      ) AS newly_unlocked,
      COALESCE(sum((assembled.badge->>'points_awarded')::integer), 0)::integer
        AS visit_badge_points,
      COALESCE(
        sum((assembled.badge->>'points_awarded')::integer)
          FILTER (WHERE assembled.is_new),
        0
      )::integer AS new_badge_points
    FROM assembled
  ) AS result;

  v_badges := v_preserved_badges || v_visit_badges;

  v_total_points := greatest(
    0,
    v_old_points
      - (v_old_visit_count * 50)
      - v_old_badge_points
      + (v_visit_count * 50)
      + v_visit_badge_points
  );

  UPDATE public.leaderboard
  SET places_visited = v_visit_count,
      total_points = v_total_points,
      level = CASE
        WHEN v_total_points >= 5000 THEN 'Lorekeeper'
        WHEN v_total_points >= 2000 THEN 'Cartographer'
        WHEN v_total_points >= 500 THEN 'Wanderer'
        ELSE 'Explorer'
      END,
      badges = v_badges
  WHERE user_id = target_user_id::text;

  UPDATE public.profiles
  SET xp = v_total_points,
      badges = v_badges,
      updated_at = statement_timestamp()
  WHERE user_id = target_user_id;

  RETURN jsonb_build_object(
    'ok', true,
    'added_count', v_added,
    'removed_count', v_removed,
    'places_visited', v_visit_count,
    'total_points', v_total_points,
    'xp', v_total_points,
    'badges', v_badges,
    'newly_unlocked', v_newly_unlocked,
    'visited_place_ids', (
      SELECT COALESCE(
        jsonb_agg(checkin.place_id ORDER BY checkin.checked_in_at DESC),
        '[]'::jsonb
      )
      FROM public.place_checkins AS checkin
      WHERE checkin.user_id = target_user_id
    )
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_manage_user_visits(uuid, text[], text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_manage_user_visits(uuid, text[], text)
  TO service_role;

REVOKE ALL ON FUNCTION public.admin_add_visits_and_sync(uuid, text[])
  FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
