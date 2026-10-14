DROP FUNCTION IF EXISTS public.search_users(text, integer);

CREATE FUNCTION public.search_users(p_query text, p_limit integer DEFAULT 30)
RETURNS TABLE (
  user_id uuid,
  username text,
  display_name text,
  is_following boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    profile.user_id,
    COALESCE(
      NULLIF(profile.username, ''),
      NULLIF(to_jsonb(leaderboard)->>'user_name', ''),
      'explorer'
    ) AS username,
    COALESCE(
      NULLIF(to_jsonb(profile)->>'display_name', ''),
      NULLIF(to_jsonb(profile)->>'full_name', ''),
      NULLIF(to_jsonb(leaderboard)->>'display_name', ''),
      NULLIF(to_jsonb(leaderboard)->>'full_name', ''),
      NULLIF(to_jsonb(leaderboard)->>'user_name', ''),
      NULLIF(profile.username, ''),
      'Explorer'
    ) AS display_name,
    EXISTS (
      SELECT 1
      FROM public.user_follows AS follows
      WHERE follows.follower_id = auth.uid()
        AND follows.following_id = profile.user_id
    ) AS is_following
  FROM public.profiles AS profile
  LEFT JOIN public.leaderboard AS leaderboard
    ON leaderboard.user_id::text = profile.user_id::text
  WHERE auth.uid() IS NOT NULL
    AND profile.user_id <> auth.uid()
    AND (
      length(btrim(COALESCE(p_query, ''))) = 0
      OR (
        length(btrim(p_query)) >= 2
        AND (
          COALESCE(profile.username, '') ILIKE '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(profile)->>'display_name', '') ILIKE
             '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(profile)->>'full_name', '') ILIKE
             '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(leaderboard)->>'display_name', '') ILIKE
             '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(leaderboard)->>'full_name', '') ILIKE
             '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(leaderboard)->>'user_name', '') ILIKE
             '%' || btrim(p_query) || '%'
        )
      )
    )
  ORDER BY
    COALESCE(leaderboard.total_points, 0) DESC,
    display_name,
    profile.user_id
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50);
$$;

REVOKE ALL ON FUNCTION public.search_users(text, integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_users(text, integer)
  TO authenticated;

DROP FUNCTION IF EXISTS public.get_following_activity(integer);

CREATE FUNCTION public.get_following_activity(p_limit integer DEFAULT 50)
RETURNS TABLE (
  event_id text,
  event_type text,
  actor_id text,
  actor_username text,
  target_id text,
  title text,
  description text,
  occurred_at timestamptz,
  actor_display_name text,
  place_id text,
  place_name text,
  place_name_ar text,
  place_image_url text,
  place_lat double precision,
  place_lng double precision
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH followed_users AS (
    SELECT follows.following_id::text AS uid
    FROM public.user_follows AS follows
    WHERE follows.follower_id::text = auth.uid()::text
  ),
  activities AS (
    SELECT
      ('checkin:' || COALESCE(
        to_jsonb(checkins)->>'id',
        md5(
          checkins.user_id::text || ':' || checkins.place_id::text || ':' ||
          COALESCE(checkins.checked_in_at::text, '')
        )
      ))::text AS event_id,
      'checkin'::text AS event_type,
      checkins.user_id::text AS actor_id,
      COALESCE(profile.username, to_jsonb(leaderboard)->>'user_name', 'explorer')
        ::text AS actor_username,
      checkins.place_id::text AS target_id,
      COALESCE(
        NULLIF(to_jsonb(places)->>'name_en', ''),
        NULLIF(to_jsonb(places)->>'name', ''),
        checkins.place_id::text
      )::text AS title,
      'Checked in at a place'::text AS description,
      checkins.checked_in_at::timestamptz AS occurred_at,
      COALESCE(
        NULLIF(to_jsonb(profile)->>'display_name', ''),
        NULLIF(to_jsonb(profile)->>'full_name', ''),
        NULLIF(to_jsonb(leaderboard)->>'display_name', ''),
        NULLIF(to_jsonb(leaderboard)->>'full_name', ''),
        NULLIF(to_jsonb(leaderboard)->>'user_name', ''),
        profile.username,
        'Explorer'
      )::text AS actor_display_name,
      checkins.place_id::text AS place_id,
      COALESCE(
        NULLIF(to_jsonb(places)->>'name_en', ''),
        NULLIF(to_jsonb(places)->>'name', '')
      )::text AS place_name,
      NULLIF(to_jsonb(places)->>'name_ar', '')::text AS place_name_ar,
      COALESCE(
        NULLIF(to_jsonb(places)->>'image_url', ''),
        NULLIF(to_jsonb(places)->'image_urls'->>0, '')
      )::text AS place_image_url,
      places.lat::double precision AS place_lat,
      places.lng::double precision AS place_lng
    FROM public.place_checkins AS checkins
    JOIN followed_users ON followed_users.uid = checkins.user_id::text
    LEFT JOIN public.profiles AS profile
      ON profile.user_id::text = checkins.user_id::text
    LEFT JOIN public.leaderboard AS leaderboard
      ON leaderboard.user_id::text = checkins.user_id::text
    LEFT JOIN public.places AS places
      ON places.id::text = checkins.place_id::text

    UNION ALL

    SELECT
      ('badge:' || leaderboard.user_id::text || ':' ||
        COALESCE(badge->>'id', ''))::text,
      'badge'::text,
      leaderboard.user_id::text,
      COALESCE(profile.username, to_jsonb(leaderboard)->>'user_name', 'explorer')
        ::text,
      COALESCE(badge->>'id', '')::text,
      COALESCE(badge->>'name', badge->>'id', 'Achievement')::text,
      COALESCE(badge->>'description', 'Unlocked an achievement')::text,
      COALESCE(
        NULLIF(badge->>'earned_at', '')::timestamptz,
        NULLIF(to_jsonb(leaderboard)->>'updated_at', '')::timestamptz
      ),
      COALESCE(
        NULLIF(to_jsonb(profile)->>'display_name', ''),
        NULLIF(to_jsonb(profile)->>'full_name', ''),
        NULLIF(to_jsonb(leaderboard)->>'display_name', ''),
        NULLIF(to_jsonb(leaderboard)->>'full_name', ''),
        NULLIF(to_jsonb(leaderboard)->>'user_name', ''),
        profile.username,
        'Explorer'
      )::text,
      NULL::text,
      NULL::text,
      NULL::text,
      NULL::text,
      NULL::double precision,
      NULL::double precision
    FROM public.leaderboard AS leaderboard
    JOIN followed_users ON followed_users.uid = leaderboard.user_id::text
    LEFT JOIN public.profiles AS profile
      ON profile.user_id::text = leaderboard.user_id::text
    CROSS JOIN LATERAL jsonb_array_elements(
      CASE
        WHEN jsonb_typeof(COALESCE(leaderboard.badges::jsonb, '[]'::jsonb)) = 'array'
          THEN COALESCE(leaderboard.badges::jsonb, '[]'::jsonb)
        ELSE '[]'::jsonb
      END
    ) AS badge
    WHERE jsonb_typeof(badge) = 'object'

    UNION ALL

    SELECT
      ('suggestion:' || suggestions.id::text)::text,
      'suggestion'::text,
      suggestions.user_id::text,
      COALESCE(profile.username, to_jsonb(leaderboard)->>'user_name', 'explorer')
        ::text,
      suggestions.id::text,
      suggestions.title::text,
      suggestions.description::text,
      suggestions.created_at::timestamptz,
      COALESCE(
        NULLIF(to_jsonb(profile)->>'display_name', ''),
        NULLIF(to_jsonb(profile)->>'full_name', ''),
        NULLIF(to_jsonb(leaderboard)->>'display_name', ''),
        NULLIF(to_jsonb(leaderboard)->>'full_name', ''),
        NULLIF(to_jsonb(leaderboard)->>'user_name', ''),
        profile.username,
        'Explorer'
      )::text,
      NULL::text,
      NULL::text,
      NULL::text,
      NULL::text,
      NULL::double precision,
      NULL::double precision
    FROM public.suggested_places AS suggestions
    JOIN followed_users ON followed_users.uid = suggestions.user_id::text
    LEFT JOIN public.profiles AS profile
      ON profile.user_id::text = suggestions.user_id::text
    LEFT JOIN public.leaderboard AS leaderboard
      ON leaderboard.user_id::text = suggestions.user_id::text
    WHERE suggestions.status = 'approved'
  )
  SELECT
    activities.event_id,
    activities.event_type,
    activities.actor_id,
    activities.actor_username,
    activities.target_id,
    activities.title,
    activities.description,
    activities.occurred_at,
    activities.actor_display_name,
    activities.place_id,
    activities.place_name,
    activities.place_name_ar,
    activities.place_image_url,
    activities.place_lat,
    activities.place_lng
  FROM activities
  ORDER BY activities.occurred_at DESC NULLS LAST
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 100));
END;
$$;

REVOKE ALL ON FUNCTION public.get_following_activity(integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_following_activity(integer)
  TO authenticated;
