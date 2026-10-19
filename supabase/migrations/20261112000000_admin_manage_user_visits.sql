WITH duplicate_checkins AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY user_id, place_id
      ORDER BY checked_in_at NULLS LAST, id
    ) AS duplicate_number
  FROM public.place_checkins
)
DELETE FROM public.place_checkins AS checkins
USING duplicate_checkins
WHERE checkins.id = duplicate_checkins.id
  AND duplicate_checkins.duplicate_number > 1;

CREATE UNIQUE INDEX IF NOT EXISTS place_checkins_user_place_unique
  ON public.place_checkins (user_id, place_id);

CREATE OR REPLACE FUNCTION public.admin_manage_user_visits(
  target_user_id uuid,
  place_ids text[],
  operation text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_added integer := 0;
  v_removed integer := 0;
  v_visit_count integer := 0;
  v_total_points integer := 0;
  v_old_badge_points integer := 0;
  v_new_badge_points integer := 0;
  v_badges jsonb := '[]'::jsonb;
  v_newly_unlocked jsonb := '[]'::jsonb;
  v_visit_badge_ids text[] := ARRAY[
    'first_steps', 'explorer_5', 'explorer_10', 'explorer_25',
    'lorekeeper', 'culture_buff', 'history_nerd', 'foodie', 'gourmet',
    'shopaholic', 'spiritual_seeker', 'pilgrim', 'hidden_gem_hunter',
    'early_bird', 'night_owl', 'completionist'
  ];
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Admin service role is required';
  END IF;
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'target_user_id is required';
  END IF;
  IF operation NOT IN ('add', 'remove') THEN
    RAISE EXCEPTION 'Unsupported visit operation';
  END IF;
  IF place_ids IS NULL OR cardinality(place_ids) = 0 THEN
    RAISE EXCEPTION 'At least one place_id is required';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM unnest(place_ids) AS requested(place_id)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.places AS places
      WHERE places.id::text = requested.place_id
    )
  ) THEN
    RAISE EXCEPTION 'One or more place_ids do not exist';
  END IF;

  INSERT INTO public.leaderboard (user_id, user_name)
  VALUES (target_user_id, 'Explorer')
  ON CONFLICT (user_id) DO NOTHING;

  PERFORM 1
  FROM public.leaderboard
  WHERE user_id = target_user_id
  FOR UPDATE;

  IF operation = 'add' THEN
    INSERT INTO public.place_checkins (user_id, place_id, checked_in_at)
    SELECT target_user_id, requested.place_id, statement_timestamp()
    FROM (
      SELECT DISTINCT unnest(place_ids) AS place_id
    ) AS requested
    ON CONFLICT (user_id, place_id) DO NOTHING;
    GET DIAGNOSTICS v_added = ROW_COUNT;
  ELSE
    DELETE FROM public.place_checkins AS checkins
    WHERE checkins.user_id = target_user_id
      AND checkins.place_id = ANY(place_ids);
    GET DIAGNOSTICS v_removed = ROW_COUNT;
  END IF;

  SELECT count(*)::integer
  INTO v_visit_count
  FROM public.place_checkins
  WHERE user_id = target_user_id;

  WITH visit_counts AS (
    SELECT
      count(*)::integer AS all_visits,
      count(*) FILTER (
        WHERE places.category IN ('Culture', 'Historical')
      )::integer AS culture_visits,
      count(*) FILTER (WHERE places.category = 'Food')::integer AS food_visits,
      count(*) FILTER (
        WHERE places.category = 'Shopping'
      )::integer AS shopping_visits,
      count(*) FILTER (
        WHERE places.category = 'Mosques'
      )::integer AS mosque_visits,
      count(*) FILTER (
        WHERE places.category = 'Churches'
      )::integer AS church_visits,
      count(*) FILTER (
        WHERE places.is_hidden_gem IS TRUE
      )::integer AS hidden_gem_visits
    FROM public.place_checkins AS checkins
    JOIN public.places AS places
      ON places.id::text = checkins.place_id
    WHERE checkins.user_id = target_user_id
  ),
  completed_tours AS (
    SELECT count(*)::integer AS tour_count
    FROM public.tours AS tours
    WHERE EXISTS (
      SELECT 1
      FROM public.tour_places AS tour_places
      WHERE tour_places.tour_id = tours.id
    )
      AND NOT EXISTS (
        SELECT 1
        FROM public.tour_places AS tour_places
        WHERE tour_places.tour_id = tours.id
          AND NOT EXISTS (
            SELECT 1
            FROM public.place_checkins AS checkins
            WHERE checkins.user_id = target_user_id
              AND checkins.place_id = tour_places.place_id::text
          )
      )
  ),
  eligible_badges AS (
    SELECT
      badge.id,
      badge.name,
      badge.description,
      badge.icon_name,
      badge.tier,
      badge.points
    FROM visit_counts
    CROSS JOIN completed_tours
    CROSS JOIN (VALUES
      ('first_steps', 'ach_first_steps_name', 'ach_first_steps_desc', 'flag_rounded', 'bronze', 10, all_visits >= 1),
      ('explorer_5', 'ach_explorer_5_name', 'ach_explorer_5_desc', 'explore_rounded', 'bronze', 25, all_visits >= 5),
      ('explorer_10', 'ach_explorer_10_name', 'ach_explorer_10_desc', 'travel_explore_rounded', 'silver', 50, all_visits >= 10),
      ('explorer_25', 'ach_explorer_25_name', 'ach_explorer_25_desc', 'public_rounded', 'gold', 100, all_visits >= 25),
      ('lorekeeper', 'ach_lorekeeper_name', 'ach_lorekeeper_desc', 'workspace_premium_rounded', 'platinum', 500, all_visits >= 42),
      ('culture_buff', 'ach_culture_buff_name', 'ach_culture_buff_desc', 'museum_rounded', 'silver', 40, culture_visits >= 5),
      ('history_nerd', 'ach_history_nerd_name', 'ach_history_nerd_desc', 'account_balance_rounded', 'gold', 80, culture_visits >= 10),
      ('foodie', 'ach_foodie_name', 'ach_foodie_desc', 'restaurant_rounded', 'bronze', 30, food_visits >= 3),
      ('gourmet', 'ach_gourmet_name', 'ach_gourmet_desc', 'local_dining_rounded', 'gold', 75, food_visits >= 8),
      ('shopaholic', 'ach_shopaholic_name', 'ach_shopaholic_desc', 'shopping_bag_rounded', 'silver', 35, shopping_visits >= 3),
      ('spiritual_seeker', 'ach_spiritual_seeker_name', 'ach_spiritual_seeker_desc', 'mosque_rounded', 'silver', 35, mosque_visits >= 2),
      ('pilgrim', 'ach_pilgrim_name', 'ach_pilgrim_desc', 'church_rounded', 'gold', 50, church_visits >= 2),
      ('hidden_gem_hunter', 'ach_hidden_gem_hunter_name', 'ach_hidden_gem_hunter_desc', 'diamond_rounded', 'gold', 75, hidden_gem_visits >= 3),
      ('early_bird', 'ach_early_bird_name', 'ach_early_bird_desc', 'wb_sunny_rounded', 'bronze', 40, all_visits >= 5),
      ('night_owl', 'ach_night_owl_name', 'ach_night_owl_desc', 'nightlight_rounded', 'bronze', 40, all_visits >= 5),
      ('completionist', 'ach_completionist_name', 'ach_completionist_desc', 'check_circle_rounded', 'platinum', 500, tour_count >= 20)
    ) AS badge(id, name, description, icon_name, tier, points, eligible)
    WHERE badge.eligible
  ),
  old_badges AS (
    SELECT badge
    FROM public.leaderboard AS leaderboard
    CROSS JOIN LATERAL jsonb_array_elements(
      CASE
        WHEN jsonb_typeof(leaderboard.badges) = 'array'
          THEN leaderboard.badges
        ELSE '[]'::jsonb
      END
    ) AS badge
    WHERE leaderboard.user_id = target_user_id
  ),
  preserved_badges AS (
    SELECT badge
    FROM old_badges
    WHERE NOT (badge->>'id' = ANY(v_visit_badge_ids))
  ),
  assembled_badges AS (
    SELECT badge FROM preserved_badges
    UNION ALL
    SELECT jsonb_build_object(
      'id', eligible.id,
      'name', eligible.name,
      'description', eligible.description,
      'icon_name', eligible.icon_name,
      'tier', eligible.tier,
      'earned_at', COALESCE(
        old.badge->>'earned_at',
        statement_timestamp()::text
      ),
      'points_awarded', eligible.points
    )
    FROM eligible_badges AS eligible
    LEFT JOIN old_badges AS old
      ON old.badge->>'id' = eligible.id
  )
  SELECT
    COALESCE(jsonb_agg(assembled_badges.badge), '[]'::jsonb),
    COALESCE(sum((assembled_badges.badge->>'points_awarded')::integer)
      FILTER (WHERE assembled_badges.badge->>'id' = ANY(v_visit_badge_ids)), 0)
  INTO v_badges, v_new_badge_points
  FROM assembled_badges;

  SELECT COALESCE(sum((badge->>'points_awarded')::integer), 0)
  INTO v_old_badge_points
  FROM public.leaderboard AS leaderboard
  CROSS JOIN LATERAL jsonb_array_elements(
    CASE
      WHEN jsonb_typeof(leaderboard.badges) = 'array'
        THEN leaderboard.badges
      ELSE '[]'::jsonb
    END
  ) AS badge
  WHERE leaderboard.user_id = target_user_id
    AND badge->>'id' = ANY(v_visit_badge_ids);

  SELECT COALESCE(
    jsonb_agg(jsonb_build_object(
      'id', eligible.id,
      'name', eligible.name,
      'description', eligible.description,
      'icon_name', eligible.icon_name,
      'tier', eligible.tier,
      'earned_at', statement_timestamp()::text,
      'points_awarded', eligible.points
    )),
    '[]'::jsonb
  )
  INTO v_newly_unlocked
  FROM (
    SELECT badge.id, badge.name, badge.description, badge.icon_name,
      badge.tier, badge.points
    FROM (
      SELECT
        count(*)::integer AS all_visits,
        count(*) FILTER (WHERE places.category IN ('Culture', 'Historical'))::integer AS culture_visits,
        count(*) FILTER (WHERE places.category = 'Food')::integer AS food_visits,
        count(*) FILTER (WHERE places.category = 'Shopping')::integer AS shopping_visits,
        count(*) FILTER (WHERE places.category = 'Mosques')::integer AS mosque_visits,
        count(*) FILTER (WHERE places.category = 'Churches')::integer AS church_visits,
        count(*) FILTER (WHERE places.is_hidden_gem IS TRUE)::integer AS hidden_gem_visits
      FROM public.place_checkins AS checkins
      JOIN public.places AS places ON places.id::text = checkins.place_id
      WHERE checkins.user_id = target_user_id
    ) AS counts
    CROSS JOIN (VALUES
      ('first_steps', 'ach_first_steps_name', 'ach_first_steps_desc', 'flag_rounded', 'bronze', 10, all_visits >= 1),
      ('explorer_5', 'ach_explorer_5_name', 'ach_explorer_5_desc', 'explore_rounded', 'bronze', 25, all_visits >= 5),
      ('explorer_10', 'ach_explorer_10_name', 'ach_explorer_10_desc', 'travel_explore_rounded', 'silver', 50, all_visits >= 10),
      ('explorer_25', 'ach_explorer_25_name', 'ach_explorer_25_desc', 'public_rounded', 'gold', 100, all_visits >= 25),
      ('lorekeeper', 'ach_lorekeeper_name', 'ach_lorekeeper_desc', 'workspace_premium_rounded', 'platinum', 500, all_visits >= 42),
      ('culture_buff', 'ach_culture_buff_name', 'ach_culture_buff_desc', 'museum_rounded', 'silver', 40, culture_visits >= 5),
      ('history_nerd', 'ach_history_nerd_name', 'ach_history_nerd_desc', 'account_balance_rounded', 'gold', 80, culture_visits >= 10),
      ('foodie', 'ach_foodie_name', 'ach_foodie_desc', 'restaurant_rounded', 'bronze', 30, food_visits >= 3),
      ('gourmet', 'ach_gourmet_name', 'ach_gourmet_desc', 'local_dining_rounded', 'gold', 75, food_visits >= 8),
      ('shopaholic', 'ach_shopaholic_name', 'ach_shopaholic_desc', 'shopping_bag_rounded', 'silver', 35, shopping_visits >= 3),
      ('spiritual_seeker', 'ach_spiritual_seeker_name', 'ach_spiritual_seeker_desc', 'mosque_rounded', 'silver', 35, mosque_visits >= 2),
      ('pilgrim', 'ach_pilgrim_name', 'ach_pilgrim_desc', 'church_rounded', 'gold', 50, church_visits >= 2),
      ('hidden_gem_hunter', 'ach_hidden_gem_hunter_name', 'ach_hidden_gem_hunter_desc', 'diamond_rounded', 'gold', 75, hidden_gem_visits >= 3),
      ('early_bird', 'ach_early_bird_name', 'ach_early_bird_desc', 'wb_sunny_rounded', 'bronze', 40, all_visits >= 5),
      ('night_owl', 'ach_night_owl_name', 'ach_night_owl_desc', 'nightlight_rounded', 'bronze', 40, all_visits >= 5)
    ) AS badge(id, name, description, icon_name, tier, points, eligible)
    WHERE badge.eligible
      AND NOT EXISTS (
        SELECT 1 FROM public.leaderboard AS prior
        CROSS JOIN LATERAL jsonb_array_elements(
          CASE
            WHEN jsonb_typeof(prior.badges) = 'array'
              THEN prior.badges
            ELSE '[]'::jsonb
          END
        ) AS prior_badge
        WHERE prior.user_id = target_user_id
          AND prior_badge->>'id' = badge.id
      )
  ) AS eligible;

  IF (
    SELECT count(*)
    FROM public.tours AS tours
    WHERE EXISTS (
      SELECT 1
      FROM public.tour_places AS tour_places
      WHERE tour_places.tour_id = tours.id
    )
      AND NOT EXISTS (
        SELECT 1
        FROM public.tour_places AS tour_places
        WHERE tour_places.tour_id = tours.id
          AND NOT EXISTS (
            SELECT 1
            FROM public.place_checkins AS checkins
            WHERE checkins.user_id = target_user_id
              AND checkins.place_id = tour_places.place_id
          )
      )
  ) >= 20 AND NOT EXISTS (
    SELECT 1
    FROM public.leaderboard AS prior
    CROSS JOIN LATERAL jsonb_array_elements(
      CASE
        WHEN jsonb_typeof(prior.badges) = 'array'
          THEN prior.badges
        ELSE '[]'::jsonb
      END
    ) AS prior_badge
    WHERE prior.user_id = target_user_id
      AND prior_badge->>'id' = 'completionist'
  ) THEN
    v_newly_unlocked := v_newly_unlocked || jsonb_build_array(
      jsonb_build_object(
        'id', 'completionist',
        'name', 'ach_completionist_name',
        'description', 'ach_completionist_desc',
        'icon_name', 'check_circle_rounded',
        'tier', 'platinum',
        'earned_at', statement_timestamp()::text,
        'points_awarded', 500
      )
    );
  END IF;

  SELECT COALESCE(total_points, 0)
  INTO v_total_points
  FROM public.leaderboard
  WHERE user_id = target_user_id;
  v_total_points := greatest(
    0,
    v_total_points
      + (v_added - v_removed) * 50
      - v_old_badge_points
      + v_new_badge_points
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
      badges = v_badges,
      updated_at = statement_timestamp()
  WHERE user_id = target_user_id;

  RETURN jsonb_build_object(
    'added_count', v_added,
    'removed_count', v_removed,
    'places_visited', v_visit_count,
    'total_points', v_total_points,
    'badges', v_badges,
    'newly_unlocked', v_newly_unlocked,
    'visited_place_ids', (
      SELECT COALESCE(jsonb_agg(checkins.place_id ORDER BY checkins.checked_in_at DESC), '[]'::jsonb)
      FROM public.place_checkins AS checkins
      WHERE checkins.user_id = target_user_id
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_manage_user_visits(uuid, text[], text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_manage_user_visits(uuid, text[], text)
  TO service_role;
