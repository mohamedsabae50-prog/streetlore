ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_url text,
  ADD COLUMN IF NOT EXISTS share_location_activity boolean NOT NULL DEFAULT true;

UPDATE public.profiles
SET share_location_activity = true
WHERE share_location_activity IS NULL;

GRANT UPDATE (avatar_url, share_location_activity)
  ON public.profiles TO authenticated;

DROP POLICY IF EXISTS "users can update own profile username" ON public.profiles;
CREATE POLICY "users can update own profile username"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.friendships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT friendships_no_self CHECK (requester_id <> recipient_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS friendships_pair_unique
  ON public.friendships (
    LEAST(requester_id, recipient_id),
    GREATEST(requester_id, recipient_id)
  );
CREATE INDEX IF NOT EXISTS friendships_incoming_pending_idx
  ON public.friendships (recipient_id, created_at DESC)
  WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS friendships_requester_pending_idx
  ON public.friendships (requester_id, created_at DESC)
  WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS place_checkins_user_checked_at_idx
  ON public.place_checkins (user_id, checked_in_at DESC);

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users can read their friendships" ON public.friendships;
CREATE POLICY "users can read their friendships"
  ON public.friendships
  FOR SELECT
  TO authenticated
  USING (auth.uid() IN (requester_id, recipient_id));

REVOKE ALL ON public.friendships FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.friendships TO authenticated;

DROP POLICY IF EXISTS "users can follow from their own account"
  ON public.user_follows;
DROP POLICY IF EXISTS "users can unfollow from their own account"
  ON public.user_follows;
REVOKE INSERT, DELETE ON public.user_follows FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.send_friend_request(target_user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  current_user_id uuid := auth.uid();
  existing_request public.friendships%ROWTYPE;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF target_user_id IS NULL OR target_user_id = current_user_id THEN
    RAISE EXCEPTION 'Invalid friend request target' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(
    LEAST(current_user_id, target_user_id)::text || ':' ||
    GREATEST(current_user_id, target_user_id)::text,
    0
  ));

  SELECT *
  INTO existing_request
  FROM public.friendships
  WHERE LEAST(requester_id, recipient_id) =
        LEAST(current_user_id, target_user_id)
    AND GREATEST(requester_id, recipient_id) =
        GREATEST(current_user_id, target_user_id)
  FOR UPDATE;

  IF FOUND THEN
    IF existing_request.status = 'accepted' THEN
      RETURN 'accepted';
    END IF;
    IF existing_request.status = 'pending' THEN
      RETURN CASE
        WHEN existing_request.requester_id = current_user_id THEN 'outgoing'
        ELSE 'incoming'
      END;
    END IF;

    UPDATE public.friendships
    SET requester_id = current_user_id,
        recipient_id = target_user_id,
        status = 'pending',
        created_at = now(),
        updated_at = now()
    WHERE id = existing_request.id;
    RETURN 'outgoing';
  END IF;

  INSERT INTO public.friendships (requester_id, recipient_id, status)
  VALUES (current_user_id, target_user_id, 'pending');
  RETURN 'outgoing';
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_to_friend_request(
  request_id uuid,
  accept_request boolean
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  next_status text := CASE WHEN accept_request THEN 'accepted' ELSE 'rejected' END;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  UPDATE public.friendships
  SET status = next_status,
      updated_at = now()
  WHERE id = request_id
    AND recipient_id = auth.uid()
    AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Incoming friend request not found' USING ERRCODE = 'P0002';
  END IF;
  RETURN next_status;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_friend_request(request_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.friendships
  WHERE id = request_id
    AND requester_id = auth.uid()
    AND status = 'pending';
  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_friend(target_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.friendships
  WHERE status = 'accepted'
    AND LEAST(requester_id, recipient_id) =
        LEAST(auth.uid(), target_user_id)
    AND GREATEST(requester_id, recipient_id) =
        GREATEST(auth.uid(), target_user_id);
  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.send_friend_request(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.respond_to_friend_request(uuid, boolean)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cancel_friend_request(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.remove_friend(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_friend_request(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_friend_request(uuid, boolean)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_friend_request(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_friend(uuid) TO authenticated;

CREATE TABLE IF NOT EXISTS public.friend_privacy_settings (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  friend_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  share_location_activity boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, friend_id),
  CONSTRAINT friend_privacy_no_self CHECK (user_id <> friend_id)
);

ALTER TABLE public.friend_privacy_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.friend_privacy_settings FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS "users can read own friend privacy settings"
  ON public.friend_privacy_settings;
CREATE POLICY "users can read own friend privacy settings"
  ON public.friend_privacy_settings
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());
DROP POLICY IF EXISTS "users can manage own friend privacy settings"
  ON public.friend_privacy_settings;
CREATE POLICY "users can manage own friend privacy settings"
  ON public.friend_privacy_settings
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.friendships AS friendship
      WHERE friendship.status = 'accepted'
        AND LEAST(friendship.requester_id, friendship.recipient_id) =
            LEAST(user_id, friend_id)
        AND GREATEST(friendship.requester_id, friendship.recipient_id) =
            GREATEST(user_id, friend_id)
    )
  );
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.friend_privacy_settings TO authenticated;

CREATE OR REPLACE FUNCTION public.can_view_user_activity(target_user_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT auth.uid() IS NOT NULL
    AND (
      target_user_id = auth.uid()::text
      OR (
        EXISTS (
          SELECT 1
          FROM public.profiles AS profile
          WHERE profile.user_id::text = target_user_id
            AND profile.share_location_activity IS TRUE
        )
        AND EXISTS (
          SELECT 1
          FROM public.friendships AS friendship
          WHERE friendship.status = 'accepted'
            AND (
              (
                friendship.requester_id = auth.uid()
                AND friendship.recipient_id::text = target_user_id
              )
              OR (
                friendship.recipient_id = auth.uid()
                AND friendship.requester_id::text = target_user_id
              )
            )
        )
        AND NOT EXISTS (
          SELECT 1
          FROM public.friend_privacy_settings AS privacy
          WHERE privacy.user_id::text = target_user_id
            AND privacy.friend_id = auth.uid()
            AND privacy.share_location_activity IS FALSE
        )
      )
    );
$$;

REVOKE ALL ON FUNCTION public.can_view_user_activity(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_view_user_activity(text) TO authenticated;

DO $$
DECLARE
  policy_row record;
BEGIN
  FOR policy_row IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'place_checkins'
      AND cmd IN ('SELECT', 'ALL')
  LOOP
    EXECUTE format(
      'DROP POLICY %I ON public.place_checkins',
      policy_row.policyname
    );
  END LOOP;
END;
$$;

CREATE POLICY "users can read own and shared friend checkins"
  ON public.place_checkins
  FOR SELECT
  TO authenticated
  USING (public.can_view_user_activity(user_id::text));
DROP POLICY IF EXISTS "users can manage own place checkins"
  ON public.place_checkins;
CREATE POLICY "users can manage own place checkins"
  ON public.place_checkins
  FOR ALL
  TO authenticated
  USING (user_id::text = auth.uid()::text)
  WITH CHECK (user_id::text = auth.uid()::text);

CREATE OR REPLACE FUNCTION public.get_user_visited_places(target_user_id uuid)
RETURNS TABLE (
  id text,
  name_en text,
  name_ar text,
  description_en text,
  description_ar text,
  image_url text,
  image_urls text[],
  category text,
  lat double precision,
  lng double precision,
  address text,
  address_ar text,
  checked_in_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    places.id::text,
    COALESCE(NULLIF(to_jsonb(places)->>'name_en', ''), places.name),
    NULLIF(to_jsonb(places)->>'name_ar', ''),
    COALESCE(NULLIF(to_jsonb(places)->>'description_en', ''), places.description),
    NULLIF(to_jsonb(places)->>'description_ar', ''),
    places.image_url,
    COALESCE(places.image_urls, ARRAY[]::text[]),
    places.category,
    places.lat::double precision,
    places.lng::double precision,
    places.address,
    NULLIF(to_jsonb(places)->>'address_ar', ''),
    checkins.checked_in_at::timestamptz
  FROM public.place_checkins AS checkins
  JOIN public.places AS places
    ON places.id::text = checkins.place_id::text
  WHERE public.can_view_user_activity(target_user_id::text)
    AND checkins.user_id::text = target_user_id::text
  ORDER BY checkins.checked_in_at DESC NULLS LAST, places.id;
$$;

REVOKE ALL ON FUNCTION public.get_user_visited_places(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_visited_places(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.get_following_activity(integer);
CREATE FUNCTION public.get_following_activity(p_limit integer DEFAULT 50)
RETURNS TABLE(
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
  WITH friend_users AS (
    SELECT CASE
      WHEN friendship.requester_id = auth.uid()
        THEN friendship.recipient_id::text
      ELSE friendship.requester_id::text
    END AS uid
    FROM public.friendships AS friendship
    WHERE friendship.status = 'accepted'
      AND auth.uid() IN (friendship.requester_id, friendship.recipient_id)
  ),
  activities AS (
    SELECT
      ('checkin:' || COALESCE(
        to_jsonb(checkins)->>'id',
        md5(checkins.user_id::text || ':' || checkins.place_id::text || ':' ||
            COALESCE(checkins.checked_in_at::text, ''))
      ))::text AS event_id,
      'checkin'::text AS event_type,
      checkins.user_id::text AS actor_id,
      COALESCE(profile.username, to_jsonb(leaderboard)->>'user_name', 'explorer')::text,
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
    JOIN friend_users ON friend_users.uid = checkins.user_id::text
    LEFT JOIN public.profiles AS profile
      ON profile.user_id::text = checkins.user_id::text
    LEFT JOIN public.leaderboard AS leaderboard
      ON leaderboard.user_id::text = checkins.user_id::text
    LEFT JOIN public.places AS places
      ON places.id::text = checkins.place_id::text
    WHERE public.can_view_user_activity(checkins.user_id::text)

    UNION ALL

    SELECT
      ('badge:' || leaderboard.user_id::text || ':' || COALESCE(badge->>'id', ''))::text,
      'badge'::text,
      leaderboard.user_id::text,
      COALESCE(profile.username, to_jsonb(leaderboard)->>'user_name', 'explorer')::text,
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
    JOIN friend_users ON friend_users.uid = leaderboard.user_id::text
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
      AND public.can_view_user_activity(leaderboard.user_id::text)

    UNION ALL

    SELECT
      ('suggestion:' || suggestions.id::text)::text,
      'suggestion'::text,
      suggestions.user_id::text,
      COALESCE(profile.username, to_jsonb(leaderboard)->>'user_name', 'explorer')::text,
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
    JOIN friend_users ON friend_users.uid = suggestions.user_id::text
    LEFT JOIN public.profiles AS profile
      ON profile.user_id::text = suggestions.user_id::text
    LEFT JOIN public.leaderboard AS leaderboard
      ON leaderboard.user_id::text = suggestions.user_id::text
    WHERE suggestions.status = 'approved'
      AND public.can_view_user_activity(suggestions.user_id::text)
  )
  SELECT activities.*
  FROM activities
  ORDER BY activities.occurred_at DESC NULLS LAST
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 100));
END;
$$;

REVOKE ALL ON FUNCTION public.get_following_activity(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_following_activity(integer) TO authenticated;

CREATE TABLE IF NOT EXISTS public.photo_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  photo_id text NOT NULL
    REFERENCES public.place_photos(id) ON DELETE CASCADE,
  photo_url text NOT NULL,
  uploader_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  place_id text NOT NULL REFERENCES public.places(id) ON DELETE CASCADE,
  reason text NOT NULL
    CHECK (reason IN (
      'Inappropriate content',
      'Not related to this place',
      'Offensive/Abuse',
      'Other'
    )),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT photo_reports_no_self CHECK (uploader_id <> reporter_id),
  CONSTRAINT photo_reports_unique_per_reporter UNIQUE (photo_id, reporter_id)
);

CREATE INDEX IF NOT EXISTS photo_reports_created_idx
  ON public.photo_reports (created_at DESC);
CREATE INDEX IF NOT EXISTS photo_reports_uploader_idx
  ON public.photo_reports (uploader_id, created_at DESC);

ALTER TABLE public.photo_reports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.photo_reports FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS "users can submit photo reports" ON public.photo_reports;
CREATE POLICY "users can submit photo reports"
  ON public.photo_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (
    reporter_id = auth.uid()
    AND uploader_id <> auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.place_photos AS photo
      WHERE photo.id = photo_reports.photo_id
        AND photo.user_id::text = photo_reports.uploader_id::text
        AND photo.place_id = photo_reports.place_id
        AND photo.image_url = photo_reports.photo_url
    )
  );
DROP POLICY IF EXISTS "users can read own photo reports" ON public.photo_reports;
CREATE POLICY "users can read own photo reports"
  ON public.photo_reports
  FOR SELECT
  TO authenticated
  USING (reporter_id = auth.uid());
DROP POLICY IF EXISTS "admins can read photo reports" ON public.photo_reports;
CREATE POLICY "admins can read photo reports"
  ON public.photo_reports
  FOR SELECT
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );
GRANT INSERT, SELECT ON public.photo_reports TO authenticated;

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "public can read avatars" ON storage.objects;
CREATE POLICY "public can read avatars"
  ON storage.objects
  FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'avatars');
DROP POLICY IF EXISTS "users can upload own avatar" ON storage.objects;
CREATE POLICY "users can upload own avatar"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
DROP POLICY IF EXISTS "users can update own avatar" ON storage.objects;
CREATE POLICY "users can update own avatar"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
DROP POLICY IF EXISTS "users can delete own avatar" ON storage.objects;
CREATE POLICY "users can delete own avatar"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE OR REPLACE FUNCTION public.search_users(
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
AS $$
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
      FROM public.friendships AS friendship
      WHERE friendship.status = 'accepted'
        AND LEAST(friendship.requester_id, friendship.recipient_id) =
            LEAST(auth.uid(), profile.user_id)
        AND GREATEST(friendship.requester_id, friendship.recipient_id) =
            GREATEST(auth.uid(), profile.user_id)
    ),
    COALESCE(
      NULLIF(btrim(profile.avatar_url), ''),
      NULLIF(user_account.raw_user_meta_data->>'avatar_url', ''),
      NULLIF(user_account.raw_user_meta_data->>'picture', ''),
      NULLIF(user_account.raw_user_meta_data->>'photo_url', '')
    ),
    (
      SELECT count(*)
      FROM public.friendships AS friendship
      WHERE friendship.status = 'accepted'
        AND profile.user_id IN (
          friendship.requester_id,
          friendship.recipient_id
        )
    ),
    (
      SELECT count(*)
      FROM public.friendships AS friendship
      WHERE friendship.status = 'accepted'
        AND profile.user_id IN (
          friendship.requester_id,
          friendship.recipient_id
        )
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
$$;

CREATE OR REPLACE FUNCTION public.get_public_profile(target_user_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
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
      FROM public.friendships AS friendship
      WHERE friendship.status = 'accepted'
        AND LEAST(friendship.requester_id, friendship.recipient_id) =
            LEAST(auth.uid(), profile.user_id)
        AND GREATEST(friendship.requester_id, friendship.recipient_id) =
            GREATEST(auth.uid(), profile.user_id)
    ),
    'avatar_url', COALESCE(
      NULLIF(btrim(profile.avatar_url), ''),
      NULLIF(user_account.raw_user_meta_data->>'avatar_url', ''),
      NULLIF(user_account.raw_user_meta_data->>'picture', ''),
      NULLIF(user_account.raw_user_meta_data->>'photo_url', '')
    ),
    'followers_count', (
      SELECT count(*)
      FROM public.friendships AS friendship
      WHERE friendship.status = 'accepted'
        AND profile.user_id IN (
          friendship.requester_id,
          friendship.recipient_id
        )
    ),
    'following_count', (
      SELECT count(*)
      FROM public.friendships AS friendship
      WHERE friendship.status = 'accepted'
        AND profile.user_id IN (
          friendship.requester_id,
          friendship.recipient_id
        )
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
  LIMIT 1;
$$;

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
AS $$
  SELECT
    profile.user_id,
    public_data.username,
    public_data.display_name,
    COALESCE((public_data.is_following)::boolean, false),
    public_data.avatar_url,
    COALESCE(public_data.followers_count, 0)::bigint,
    COALESCE(public_data.following_count, 0)::bigint,
    COALESCE(public_data.badges, '[]'::jsonb)
  FROM public.profiles AS profile
  CROSS JOIN LATERAL jsonb_to_record(
    public.get_public_profile(profile.user_id)
  ) AS public_data(
    user_id uuid,
    username text,
    display_name text,
    is_following boolean,
    avatar_url text,
    followers_count bigint,
    following_count bigint,
    badges jsonb
  )
  WHERE auth.uid() IS NOT NULL
    AND profile.user_id = ANY(COALESCE(p_user_ids, ARRAY[]::uuid[]));
$$;

REVOKE ALL ON FUNCTION public.search_users(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_users(text, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.get_public_profile(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_public_profile(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.get_public_profiles(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_public_profiles(uuid[]) TO authenticated;

REVOKE SELECT ON public.leaderboard FROM PUBLIC, anon, authenticated;
GRANT SELECT (
  user_id,
  user_name,
  avatar_color_hex,
  total_points,
  places_visited,
  reviews_posted,
  photos_uploaded,
  level,
  badges,
  current_streak,
  longest_streak,
  total_visit_days
) ON public.leaderboard TO authenticated;

CREATE OR REPLACE FUNCTION public.get_city_leaderboard(
  p_period text DEFAULT 'week',
  p_metric text DEFAULT 'check_ins',
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  user_id text,
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
      checkins.user_id::text AS uid,
      count(*) FILTER (
        WHERE v_since IS NULL OR checkins.checked_in_at >= v_since
      ) AS check_ins,
      count(DISTINCT checkins.place_id::text) FILTER (
        WHERE places.is_hidden_gem IS TRUE
          AND (v_since IS NULL OR checkins.checked_in_at >= v_since)
      ) AS hidden_gems
    FROM public.place_checkins AS checkins
    LEFT JOIN public.places AS places
      ON places.id::text = checkins.place_id::text
    GROUP BY checkins.user_id::text
  ),
  ranked AS (
    SELECT
      leaderboard.user_id::text AS uid,
      leaderboard.user_name::text AS user_name,
      leaderboard.avatar_color_hex::text AS avatar_color_hex,
      COALESCE(leaderboard.total_points, 0)::integer AS total_points,
      COALESCE(leaderboard.places_visited, 0)::integer AS places_visited,
      COALESCE(leaderboard.reviews_posted, 0)::integer AS reviews_posted,
      COALESCE(leaderboard.photos_uploaded, 0)::integer AS photos_uploaded,
      leaderboard.level::text AS level,
      COALESCE(leaderboard.badges::jsonb, '[]'::jsonb) AS badges,
      COALESCE(leaderboard.current_streak, 0)::integer AS current_streak,
      COALESCE(leaderboard.longest_streak, 0)::integer AS longest_streak,
      COALESCE(leaderboard.total_visit_days, 0)::integer AS total_visit_days,
      leaderboard.last_visit_date::timestamptz AS last_visit_date,
      COALESCE(checkin_rollup.check_ins, 0)::bigint AS check_ins,
      COALESCE(checkin_rollup.hidden_gems, 0)::bigint AS hidden_gems,
      (CASE p_metric
        WHEN 'check_ins' THEN COALESCE(checkin_rollup.check_ins, 0)
        WHEN 'longest_streak' THEN COALESCE(leaderboard.longest_streak, 0)
        WHEN 'hidden_gems' THEN COALESCE(checkin_rollup.hidden_gems, 0)
      END)::bigint AS score
    FROM public.leaderboard AS leaderboard
    LEFT JOIN checkin_rollup
      ON checkin_rollup.uid = leaderboard.user_id::text
  )
  SELECT
    ranked.uid,
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
    CASE
      WHEN public.can_view_user_activity(ranked.uid)
        THEN ranked.last_visit_date
      ELSE NULL
    END,
    ranked.check_ins,
    ranked.hidden_gems,
    ranked.score
  FROM ranked
  ORDER BY ranked.score DESC, ranked.total_points DESC, ranked.user_name
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 100));
END;
$$;

REVOKE ALL ON FUNCTION public.get_city_leaderboard(text, text, integer)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_city_leaderboard(text, text, integer)
  TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
