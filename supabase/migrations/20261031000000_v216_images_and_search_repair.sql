ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS display_name text;

WITH user_names AS (
  SELECT
    profile.user_id,
    COALESCE(
      NULLIF(btrim(to_jsonb(profile)->>'display_name'), ''),
      NULLIF(btrim(user_account.raw_user_meta_data->>'display_name'), ''),
      NULLIF(btrim(user_account.raw_user_meta_data->>'full_name'), ''),
      NULLIF(btrim(user_account.raw_user_meta_data->>'name'), ''),
      NULLIF(btrim(leaderboard.user_name), ''),
      NULLIF(split_part(user_account.email, '@', 1), ''),
      'Explorer'
    ) AS resolved_display_name,
    COALESCE(
      NULLIF(btrim(profile.username), ''),
      NULLIF(btrim(user_account.raw_user_meta_data->>'username'), ''),
      'user_' || replace(profile.user_id::text, '-', '')
    ) AS resolved_username
  FROM public.profiles AS profile
  JOIN auth.users AS user_account ON user_account.id = profile.user_id
  LEFT JOIN public.leaderboard AS leaderboard
    ON leaderboard.user_id::text = profile.user_id::text
)
UPDATE public.profiles AS profile
SET username = user_names.resolved_username,
    display_name = user_names.resolved_display_name
FROM user_names
WHERE profile.user_id = user_names.user_id;

INSERT INTO public.profiles (user_id, username, display_name)
SELECT
  user_account.id,
  'user_' || replace(user_account.id::text, '-', ''),
  COALESCE(
    NULLIF(btrim(user_account.raw_user_meta_data->>'display_name'), ''),
    NULLIF(btrim(user_account.raw_user_meta_data->>'full_name'), ''),
    NULLIF(btrim(user_account.raw_user_meta_data->>'name'), ''),
    NULLIF(btrim(leaderboard.user_name), ''),
    NULLIF(split_part(user_account.email, '@', 1), ''),
    'Explorer'
  )
FROM auth.users AS user_account
LEFT JOIN public.leaderboard AS leaderboard
  ON leaderboard.user_id::text = user_account.id::text
WHERE NOT EXISTS (
  SELECT 1
  FROM public.profiles AS existing_profile
  WHERE existing_profile.user_id = user_account.id
);

CREATE OR REPLACE FUNCTION public.search_users(
  p_query text,
  p_limit integer DEFAULT 30
)
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
      NULLIF(btrim(profile.username), ''),
      'user_' || replace(profile.user_id::text, '-', '')
    ),
    COALESCE(
      NULLIF(btrim(profile.display_name), ''),
      NULLIF(btrim(to_jsonb(profile)->>'full_name'), ''),
      NULLIF(btrim(leaderboard.user_name), ''),
      NULLIF(btrim(profile.username), ''),
      'Explorer'
    ),
    EXISTS (
      SELECT 1
      FROM public.user_follows AS follows
      WHERE follows.follower_id = auth.uid()
        AND follows.following_id = profile.user_id
    )
  FROM public.profiles AS profile
  LEFT JOIN public.leaderboard AS leaderboard
    ON leaderboard.user_id::text = profile.user_id::text
  WHERE auth.uid() IS NOT NULL
    AND profile.user_id <> auth.uid()
    AND NOT (
      lower(btrim(COALESCE(NULLIF(btrim(profile.username), ''), 'explorer'))) =
        'explorer'
      AND lower(btrim(COALESCE(
        NULLIF(btrim(profile.display_name), ''),
        NULLIF(to_jsonb(profile)->>'full_name', ''),
        NULLIF(leaderboard.user_name, ''),
        'explorer'
      ))) = 'explorer'
    )
    AND (
      btrim(COALESCE(p_query, '')) = ''
      OR profile.username ILIKE '%' || btrim(p_query) || '%'
      OR COALESCE(profile.display_name, '') ILIKE
         '%' || btrim(p_query) || '%'
      OR COALESCE(to_jsonb(profile)->>'full_name', '') ILIKE
         '%' || btrim(p_query) || '%'
      OR COALESCE(leaderboard.user_name, '') ILIKE
         '%' || btrim(p_query) || '%'
      OR COALESCE(to_jsonb(leaderboard)->>'display_name', '') ILIKE
         '%' || btrim(p_query) || '%'
    )
  ORDER BY COALESCE(leaderboard.total_points, 0) DESC,
           btrim(profile.username), profile.user_id
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50);
$$;

REVOKE ALL ON FUNCTION public.search_users(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_users(text, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_public_profile(target_user_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'user_id', profile.user_id,
    'username', COALESCE(
      NULLIF(btrim(profile.username), ''),
      'user_' || replace(profile.user_id::text, '-', '')
    ),
    'display_name', COALESCE(
      NULLIF(btrim(profile.display_name), ''),
      NULLIF(btrim(to_jsonb(profile)->>'full_name'), ''),
      NULLIF(btrim(leaderboard.user_name), ''),
      NULLIF(btrim(profile.username), ''),
      'Explorer'
    )
  )
  FROM public.profiles AS profile
  LEFT JOIN public.leaderboard AS leaderboard
    ON leaderboard.user_id::text = profile.user_id::text
  WHERE auth.uid() IS NOT NULL
    AND profile.user_id = target_user_id
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_public_profile(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_public_profile(uuid) TO authenticated;

UPDATE public.places AS place
SET image_url = CASE
      WHEN place.image_url IS NULL
        OR btrim(place.image_url) = ''
        OR place.image_url ILIKE '%wikimedia.org%'
      THEN CASE
        WHEN place.category ILIKE '%hotel%'
          THEN 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1000&q=80'
        WHEN place.category ILIKE '%food%'
          OR place.category ILIKE '%restaurant%'
          THEN 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1000&q=80'
        WHEN place.category ILIKE '%mosque%'
          OR place.category ILIKE '%religious%'
          THEN 'https://images.unsplash.com/photo-1519817650390-64a93db51149?auto=format&fit=crop&w=1000&q=80'
        WHEN place.category ILIKE '%church%'
          OR place.category ILIKE '%cathedral%'
          THEN 'https://images.unsplash.com/photo-1438032005730-c779502df39b?auto=format&fit=crop&w=1000&q=80'
        WHEN place.category ILIKE '%nature%'
          OR place.category ILIKE '%beach%'
          THEN 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1000&q=80'
        WHEN place.category ILIKE '%shopping%'
          OR place.category ILIKE '%market%'
          THEN 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=1000&q=80'
        WHEN place.category ILIKE '%historical%'
          OR place.category ILIKE '%archaeological%'
          THEN 'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1000&q=80'
        ELSE
          'https://images.unsplash.com/photo-1564399579883-451a5d44ec08?auto=format&fit=crop&w=1000&q=80'
      END
      ELSE place.image_url
    END,
    image_urls = COALESCE(
      (
        SELECT array_agg(image_url ORDER BY image_url)
        FROM unnest(COALESCE(place.image_urls, ARRAY[]::text[]))
          AS image_urls(image_url)
        WHERE btrim(image_url) <> ''
          AND image_url NOT ILIKE '%wikimedia.org%'
      ),
      ARRAY[]::text[]
    )
WHERE place.image_url IS NULL
   OR btrim(place.image_url) = ''
   OR place.image_url ILIKE '%wikimedia.org%'
   OR EXISTS (
     SELECT 1
     FROM unnest(COALESCE(place.image_urls, ARRAY[]::text[]))
       AS image_urls(image_url)
     WHERE image_url ILIKE '%wikimedia.org%'
   );

UPDATE public.tours AS tour
SET image_url = CASE
  WHEN tour.title ILIKE '%religious%' OR tour.title ILIKE '%mosque%'
    THEN 'https://images.unsplash.com/photo-1519817650390-64a93db51149?auto=format&fit=crop&w=1000&q=80'
  WHEN tour.title ILIKE '%garden%' OR tour.title ILIKE '%family%'
    THEN 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1000&q=80'
  WHEN tour.title ILIKE '%hotel%' OR tour.title ILIKE '%beach%'
    THEN 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1000&q=80'
  WHEN tour.title ILIKE '%historical%'
    OR tour.title ILIKE '%roman%'
    OR tour.title ILIKE '%necropolis%'
    THEN 'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1000&q=80'
  ELSE
    'https://images.unsplash.com/photo-1564399579883-451a5d44ec08?auto=format&fit=crop&w=1000&q=80'
END
WHERE tour.image_url IS NULL
   OR btrim(tour.image_url) = ''
   OR tour.image_url ILIKE '%wikimedia.org%';
