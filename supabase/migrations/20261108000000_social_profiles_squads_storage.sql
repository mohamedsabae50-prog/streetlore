CREATE OR REPLACE FUNCTION public.get_my_storage_objects()
RETURNS TABLE(bucket_id text, name text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT objects.bucket_id, objects.name
  FROM storage.objects AS objects
  WHERE auth.uid() IS NOT NULL
    AND (
      objects.owner = auth.uid()
      OR objects.owner_id = auth.uid()::text
    );
$function$;

REVOKE ALL ON FUNCTION public.get_my_storage_objects()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_storage_objects()
  TO authenticated;

DROP FUNCTION IF EXISTS public.search_users(text, integer);
CREATE FUNCTION public.search_users(
  p_query text,
  p_limit integer DEFAULT 30
)
RETURNS TABLE(
  user_id uuid,
  username text,
  display_name text,
  is_following boolean,
  avatar_url text,
  followers_count bigint,
  following_count bigint,
  badges jsonb
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT
    profile.user_id,
    btrim(profile.username),
    COALESCE(
      NULLIF(btrim(to_jsonb(profile)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(profile)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'full_name'), ''),
      NULLIF(btrim(leaderboard.user_name), ''),
      btrim(profile.username)
    ),
    EXISTS (
      SELECT 1
      FROM public.user_follows AS follows
      WHERE follows.follower_id = auth.uid()
        AND follows.following_id = profile.user_id
    ),
    COALESCE(
      NULLIF(to_jsonb(profile)->>'avatar_url', ''),
      NULLIF(user_account.raw_user_meta_data->>'avatar_url', ''),
      NULLIF(user_account.raw_user_meta_data->>'picture', ''),
      NULLIF(user_account.raw_user_meta_data->>'photo_url', '')
    ),
    (
      SELECT count(*)
      FROM public.user_follows AS follows
      WHERE follows.following_id = profile.user_id
    ),
    (
      SELECT count(*)
      FROM public.user_follows AS follows
      WHERE follows.follower_id = profile.user_id
    ),
    CASE
      WHEN jsonb_typeof(leaderboard.badges::jsonb) = 'array'
        THEN leaderboard.badges::jsonb
      ELSE '[]'::jsonb
    END
  FROM public.profiles AS profile
  JOIN auth.users AS user_account ON user_account.id = profile.user_id
  LEFT JOIN public.leaderboard AS leaderboard
    ON leaderboard.user_id::text = profile.user_id::text
  WHERE auth.uid() IS NOT NULL
    AND profile.user_id <> auth.uid()
    AND NULLIF(btrim(profile.username), '') IS NOT NULL
    AND btrim(profile.username) NOT ILIKE 'explorer%'
    AND COALESCE(
      NULLIF(btrim(to_jsonb(profile)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(profile)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'full_name'), ''),
      NULLIF(btrim(leaderboard.user_name), ''),
      ''
    ) NOT ILIKE 'explorer%'
    AND (
      length(btrim(COALESCE(p_query, ''))) = 0
      OR (
        length(btrim(p_query)) >= 2
        AND (
          profile.username ILIKE '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(profile)->>'display_name', '') ILIKE
             '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(profile)->>'full_name', '') ILIKE
             '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(leaderboard)->>'display_name', '') ILIKE
             '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(leaderboard)->>'full_name', '') ILIKE
             '%' || btrim(p_query) || '%'
          OR COALESCE(leaderboard.user_name, '') ILIKE
             '%' || btrim(p_query) || '%'
        )
      )
    )
  ORDER BY COALESCE(leaderboard.total_points, 0) DESC,
           btrim(profile.username), profile.user_id
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50);
$function$;

REVOKE ALL ON FUNCTION public.search_users(text, integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_users(text, integer)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_public_profile(target_user_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT jsonb_build_object(
    'user_id', profile.user_id,
    'username', btrim(profile.username),
    'display_name', COALESCE(
      NULLIF(btrim(to_jsonb(profile)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(profile)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'full_name'), ''),
      NULLIF(btrim(leaderboard.user_name), ''),
      btrim(profile.username)
    ),
    'is_following', EXISTS (
      SELECT 1
      FROM public.user_follows AS follows
      WHERE follows.follower_id = auth.uid()
        AND follows.following_id = profile.user_id
    ),
    'avatar_url', COALESCE(
      NULLIF(to_jsonb(profile)->>'avatar_url', ''),
      NULLIF(user_account.raw_user_meta_data->>'avatar_url', ''),
      NULLIF(user_account.raw_user_meta_data->>'picture', ''),
      NULLIF(user_account.raw_user_meta_data->>'photo_url', '')
    ),
    'followers_count', (
      SELECT count(*)
      FROM public.user_follows AS follows
      WHERE follows.following_id = profile.user_id
    ),
    'following_count', (
      SELECT count(*)
      FROM public.user_follows AS follows
      WHERE follows.follower_id = profile.user_id
    ),
    'badges', CASE
      WHEN jsonb_typeof(leaderboard.badges::jsonb) = 'array'
        THEN leaderboard.badges::jsonb
      ELSE '[]'::jsonb
    END
  )
  FROM public.profiles AS profile
  JOIN auth.users AS user_account ON user_account.id = profile.user_id
  LEFT JOIN public.leaderboard AS leaderboard
    ON leaderboard.user_id::text = profile.user_id::text
  WHERE auth.uid() IS NOT NULL
    AND profile.user_id = target_user_id
    AND NULLIF(btrim(profile.username), '') IS NOT NULL
    AND btrim(profile.username) NOT ILIKE 'explorer%'
    AND COALESCE(
      NULLIF(btrim(to_jsonb(profile)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(profile)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'full_name'), ''),
      NULLIF(btrim(leaderboard.user_name), ''),
      ''
    ) NOT ILIKE 'explorer%'
  LIMIT 1;
$function$;

REVOKE ALL ON FUNCTION public.get_public_profile(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_public_profile(uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_public_profiles(p_user_ids uuid[])
RETURNS TABLE(
  user_id uuid,
  username text,
  display_name text,
  is_following boolean,
  avatar_url text,
  followers_count bigint,
  following_count bigint,
  badges jsonb
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT
    profile.user_id,
    btrim(profile.username),
    COALESCE(
      NULLIF(btrim(to_jsonb(profile)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(profile)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'full_name'), ''),
      NULLIF(btrim(leaderboard.user_name), ''),
      btrim(profile.username)
    ),
    EXISTS (
      SELECT 1
      FROM public.user_follows AS follows
      WHERE follows.follower_id = auth.uid()
        AND follows.following_id = profile.user_id
    ),
    COALESCE(
      NULLIF(to_jsonb(profile)->>'avatar_url', ''),
      NULLIF(user_account.raw_user_meta_data->>'avatar_url', ''),
      NULLIF(user_account.raw_user_meta_data->>'picture', ''),
      NULLIF(user_account.raw_user_meta_data->>'photo_url', '')
    ),
    (
      SELECT count(*)
      FROM public.user_follows AS follows
      WHERE follows.following_id = profile.user_id
    ),
    (
      SELECT count(*)
      FROM public.user_follows AS follows
      WHERE follows.follower_id = profile.user_id
    ),
    CASE
      WHEN jsonb_typeof(leaderboard.badges::jsonb) = 'array'
        THEN leaderboard.badges::jsonb
      ELSE '[]'::jsonb
    END
  FROM public.profiles AS profile
  JOIN auth.users AS user_account ON user_account.id = profile.user_id
  LEFT JOIN public.leaderboard AS leaderboard
    ON leaderboard.user_id::text = profile.user_id::text
  WHERE auth.uid() IS NOT NULL
    AND profile.user_id = ANY(COALESCE(p_user_ids, ARRAY[]::uuid[]))
    AND NULLIF(btrim(profile.username), '') IS NOT NULL
    AND btrim(profile.username) NOT ILIKE 'explorer%';
$function$;

REVOKE ALL ON FUNCTION public.get_public_profiles(uuid[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_public_profiles(uuid[])
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_active_squad()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_squad public.squads%ROWTYPE;
  v_member_count integer;
  v_members jsonb;
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

  SELECT
    count(*)::integer,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'user_id', member.user_id,
          'username', COALESCE(
            NULLIF(btrim(profile.username), ''),
            'user_' || replace(member.user_id::text, '-', '')
          ),
          'display_name', COALESCE(
            NULLIF(btrim(to_jsonb(profile)->>'display_name'), ''),
            NULLIF(btrim(to_jsonb(profile)->>'full_name'), ''),
            NULLIF(btrim(leaderboard.user_name), ''),
            NULLIF(btrim(profile.username), ''),
            'Explorer'
          ),
          'avatar_url', COALESCE(
            NULLIF(to_jsonb(profile)->>'avatar_url', ''),
            NULLIF(user_account.raw_user_meta_data->>'avatar_url', ''),
            NULLIF(user_account.raw_user_meta_data->>'picture', ''),
            NULLIF(user_account.raw_user_meta_data->>'photo_url', '')
          ),
          'is_leader', member.user_id = v_squad.created_by,
          'followers_count', (
            SELECT count(*)
            FROM public.user_follows AS follows
            WHERE follows.following_id = member.user_id
          ),
          'following_count', (
            SELECT count(*)
            FROM public.user_follows AS follows
            WHERE follows.follower_id = member.user_id
          ),
          'badges', CASE
            WHEN jsonb_typeof(leaderboard.badges::jsonb) = 'array'
              THEN leaderboard.badges::jsonb
            ELSE '[]'::jsonb
          END
        )
        ORDER BY member.joined_at, member.user_id
      ),
      '[]'::jsonb
    )
  INTO v_member_count, v_members
  FROM public.squad_members AS member
  JOIN auth.users AS user_account ON user_account.id = member.user_id
  LEFT JOIN public.profiles AS profile ON profile.user_id = member.user_id
  LEFT JOIN public.leaderboard AS leaderboard
    ON leaderboard.user_id::text = member.user_id::text
  WHERE member.squad_id = v_squad.id
    AND member.left_at IS NULL;

  RETURN jsonb_build_object(
    'id', v_squad.id,
    'join_code', v_squad.join_code,
    'created_by', v_squad.created_by,
    'member_count', v_member_count,
    'expires_at', v_squad.expires_at,
    'members', v_members
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_active_squad()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_active_squad()
  TO authenticated;
