-- StreetLore consolidated Supabase fixes.
-- Safe to re-run. Apply after the existing StreetLore schema migrations.

-- ---------------------------------------------------------------------------
-- Avatars: public reads; authenticated users may write only to their own path.
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "StreetLore avatars are publicly readable"
  ON storage.objects;
CREATE POLICY "StreetLore avatars are publicly readable"
  ON storage.objects
  FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users upload their own StreetLore avatar"
  ON storage.objects;
CREATE POLICY "Users upload their own StreetLore avatar"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users update their own StreetLore avatar"
  ON storage.objects;
CREATE POLICY "Users update their own StreetLore avatar"
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

-- ---------------------------------------------------------------------------
-- Public profile discovery for social surfaces. RLS exposes profiles to
-- authenticated users while write permissions remain owner-column scoped.
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_url text,
  ADD COLUMN IF NOT EXISTS xp integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS badges jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "authenticated can read public profile fields"
  ON public.profiles;
CREATE POLICY "authenticated can read public profile fields"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (true);

GRANT UPDATE (avatar_url) ON public.profiles TO authenticated;

-- Keep public profile discovery column-scoped so subscription and privacy
-- fields remain private even though every authenticated user can read names.
REVOKE SELECT ON public.profiles FROM PUBLIC, anon, authenticated;
REVOKE SELECT (
  is_pro,
  subscription_tier,
  subscription_end_date,
  share_location_activity,
  xp,
  badges
) ON public.profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT (user_id, username, avatar_url)
  ON public.profiles TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_profile_private()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT jsonb_build_object(
    'is_pro',
    COALESCE((to_jsonb(profile)->>'is_pro')::boolean, false),
    'subscription_tier',
    to_jsonb(profile)->'subscription_tier',
    'subscription_end_date',
    to_jsonb(profile)->'subscription_end_date',
    'username',
    profile.username,
    'avatar_url',
    profile.avatar_url,
    'share_location_activity',
    COALESCE(
      (to_jsonb(profile)->>'share_location_activity')::boolean,
      true
    )
  )
  FROM public.profiles AS profile
  WHERE profile.user_id = auth.uid()
  LIMIT 1;
$function$;

REVOKE ALL ON FUNCTION public.get_my_profile_private()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile_private()
  TO authenticated;

-- ---------------------------------------------------------------------------
-- Notifications inbox. Notification writes are performed by SECURITY DEFINER
-- triggers; users can only read and mark their own rows read.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  type text NOT NULL CHECK (
    type IN ('friend_request', 'friend_accepted', 'badge_unlocked')
  ),
  friendship_id uuid REFERENCES public.friendships(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  read_at timestamptz,
  CONSTRAINT notifications_not_self CHECK (
    actor_id IS NULL OR actor_id <> recipient_id OR type = 'badge_unlocked'
  )
);

CREATE INDEX IF NOT EXISTS notifications_recipient_created_idx
  ON public.notifications (recipient_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS notifications_friendship_event_unique
  ON public.notifications (recipient_id, type, friendship_id)
  WHERE friendship_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS notifications_badge_event_unique
  ON public.notifications (recipient_id, type, (metadata->>'badge_id'))
  WHERE type = 'badge_unlocked';

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.notifications FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS "Users read their own notifications"
  ON public.notifications;
CREATE POLICY "Users read their own notifications"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (recipient_id = auth.uid());
DROP POLICY IF EXISTS "Users mark their own notifications read"
  ON public.notifications;
CREATE POLICY "Users mark their own notifications read"
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (recipient_id = auth.uid())
  WITH CHECK (recipient_id = auth.uid());
GRANT SELECT ON public.notifications TO authenticated;
GRANT UPDATE (read_at) ON public.notifications TO authenticated;

CREATE OR REPLACE FUNCTION public.notify_friendship_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NEW.status = 'pending'
    AND (
      TG_OP = 'INSERT'
      OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status)
    )
  THEN
    INSERT INTO public.notifications (
      recipient_id, actor_id, type, friendship_id, title, body, metadata
    )
    VALUES (
      NEW.recipient_id,
      NEW.requester_id,
      'friend_request',
      NEW.id,
      'Friend request',
      '',
      jsonb_build_object('friendship_id', NEW.id)
    )
    ON CONFLICT (recipient_id, type, friendship_id)
      WHERE friendship_id IS NOT NULL
    DO UPDATE SET
      actor_id = EXCLUDED.actor_id,
      created_at = statement_timestamp(),
      read_at = NULL,
      metadata = EXCLUDED.metadata;
  ELSIF TG_OP = 'UPDATE'
    AND OLD.status IS DISTINCT FROM NEW.status
    AND NEW.status = 'accepted'
  THEN
    UPDATE public.notifications
    SET read_at = COALESCE(read_at, statement_timestamp())
    WHERE friendship_id = NEW.id
      AND recipient_id = NEW.recipient_id
      AND type = 'friend_request';

    INSERT INTO public.notifications (
      recipient_id, actor_id, type, friendship_id, title, body, metadata
    )
    VALUES (
      NEW.requester_id,
      NEW.recipient_id,
      'friend_accepted',
      NEW.id,
      'Friend request accepted',
      '',
      jsonb_build_object('friendship_id', NEW.id)
    )
    ON CONFLICT (recipient_id, type, friendship_id)
      WHERE friendship_id IS NOT NULL
    DO UPDATE SET
      actor_id = EXCLUDED.actor_id,
      created_at = statement_timestamp(),
      read_at = NULL,
      metadata = EXCLUDED.metadata;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS friendships_notify_insert ON public.friendships;
CREATE TRIGGER friendships_notify_insert
  AFTER INSERT ON public.friendships
  FOR EACH ROW EXECUTE FUNCTION public.notify_friendship_event();
DROP TRIGGER IF EXISTS friendships_notify_accept ON public.friendships;
CREATE TRIGGER friendships_notify_accept
  AFTER UPDATE OF status ON public.friendships
  FOR EACH ROW EXECUTE FUNCTION public.notify_friendship_event();

CREATE OR REPLACE FUNCTION public.sync_social_explorer_badges()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid;
  v_user_name text;
  v_friend_count integer;
  v_badges jsonb;
  v_total_xp integer;
  v_social_badge jsonb := jsonb_build_object(
    'id', 'social_explorer',
    'name', 'ach_social_explorer_name',
    'description', 'ach_social_explorer_desc',
    'icon_name', 'diversity_3_rounded',
    'tier', 'silver',
    'earned_at', statement_timestamp()::text,
    'points_awarded', 100
  );
BEGIN
  IF NEW.status <> 'accepted'
    OR (TG_OP = 'UPDATE' AND OLD.status = 'accepted')
  THEN
    RETURN NEW;
  END IF;

  FOR v_user_id IN
    SELECT DISTINCT accepted_user.user_id
    FROM unnest(ARRAY[NEW.requester_id, NEW.recipient_id]) AS accepted_user(user_id)
    ORDER BY accepted_user.user_id
  LOOP
    SELECT count(*)::integer
    INTO v_friend_count
    FROM public.friendships AS friendship
    WHERE friendship.status = 'accepted'
      AND v_user_id IN (friendship.requester_id, friendship.recipient_id);

    IF v_friend_count < 3 THEN
      CONTINUE;
    END IF;

    SELECT COALESCE(NULLIF(profile.username, ''), 'Explorer')
    INTO v_user_name
    FROM public.profiles AS profile
    WHERE profile.user_id = v_user_id;

    INSERT INTO public.leaderboard (user_id, user_name)
    VALUES (v_user_id::text, COALESCE(v_user_name, 'Explorer'))
    ON CONFLICT (user_id) DO NOTHING;

    PERFORM 1
    FROM public.leaderboard AS leaderboard
    WHERE leaderboard.user_id::text = v_user_id::text
    FOR UPDATE;

    SELECT
      CASE
        WHEN jsonb_typeof(leaderboard.badges) = 'array'
          THEN leaderboard.badges
        ELSE '[]'::jsonb
      END,
      COALESCE(leaderboard.total_points, 0)
    INTO v_badges, v_total_xp
    FROM public.leaderboard AS leaderboard
    WHERE leaderboard.user_id::text = v_user_id::text;

    IF NOT EXISTS (
      SELECT 1
      FROM jsonb_array_elements(v_badges) AS existing(value)
      WHERE existing.value->>'id' = 'social_explorer'
    ) THEN
      v_badges := v_badges || jsonb_build_array(v_social_badge);
      v_total_xp := v_total_xp + 100;

      UPDATE public.leaderboard
      SET badges = v_badges,
          total_points = v_total_xp,
          level = CASE
            WHEN v_total_xp >= 5000 THEN 'Lorekeeper'
            WHEN v_total_xp >= 2000 THEN 'Cartographer'
            WHEN v_total_xp >= 500 THEN 'Wanderer'
            ELSE 'Explorer'
          END,
          updated_at = statement_timestamp()
      WHERE user_id::text = v_user_id::text;
    END IF;

    UPDATE public.profiles
    SET badges = v_badges,
        xp = v_total_xp,
        updated_at = statement_timestamp()
    WHERE user_id = v_user_id;
  END LOOP;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS friendships_sync_social_badges
  ON public.friendships;
CREATE TRIGGER friendships_sync_social_badges
  AFTER UPDATE OF status ON public.friendships
  FOR EACH ROW EXECUTE FUNCTION public.sync_social_explorer_badges();

CREATE OR REPLACE FUNCTION public.notify_new_badges()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_badge jsonb;
BEGIN
  IF NEW.user_id::text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RETURN NEW;
  END IF;

  FOR v_badge IN
    SELECT current_badge.value
    FROM jsonb_array_elements(
      CASE
        WHEN jsonb_typeof(COALESCE(NEW.badges, '[]'::jsonb)) = 'array'
          THEN COALESCE(NEW.badges, '[]'::jsonb)
        ELSE '[]'::jsonb
      END
    ) AS current_badge(value)
    WHERE NOT EXISTS (
      SELECT 1
      FROM jsonb_array_elements(
        CASE
          WHEN TG_OP = 'UPDATE'
            AND jsonb_typeof(COALESCE(OLD.badges, '[]'::jsonb)) = 'array'
            THEN COALESCE(OLD.badges, '[]'::jsonb)
          ELSE '[]'::jsonb
        END
      ) AS old_badge(value)
      WHERE old_badge.value->>'id' = current_badge.value->>'id'
    )
  LOOP
    INSERT INTO public.notifications (
      recipient_id, actor_id, type, title, body, metadata
    )
    VALUES (
      NEW.user_id::text::uuid,
      NEW.user_id::text::uuid,
      'badge_unlocked',
      'Badge unlocked',
      '',
      jsonb_build_object(
        'badge_id', v_badge->>'id',
        'badge_name', v_badge->>'name',
        'badge_description', v_badge->>'description',
        'points_awarded', COALESCE((v_badge->>'points_awarded')::integer, 0)
      )
    )
    ON CONFLICT DO NOTHING;
  END LOOP;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS leaderboard_notify_new_badges
  ON public.leaderboard;
CREATE TRIGGER leaderboard_notify_new_badges
  AFTER INSERT OR UPDATE OF badges ON public.leaderboard
  FOR EACH ROW EXECUTE FUNCTION public.notify_new_badges();

DO $publication$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END;
$publication$;

-- ---------------------------------------------------------------------------
-- Atomic visit add + badge/XP sync for the Admin Panel.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_add_visits_and_sync(
  target_user_id uuid,
  place_ids text[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_added integer := 0;
  v_visit_count integer := 0;
  v_historical integer := 0;
  v_culture integer := 0;
  v_food integer := 0;
  v_nature integer := 0;
  v_total_xp integer := 0;
  v_old_badges jsonb := '[]'::jsonb;
  v_new_badges jsonb := '[]'::jsonb;
  v_all_badges jsonb := '[]'::jsonb;
  v_profile_name text;
  v_admin_allowed boolean := false;
BEGIN
  v_admin_allowed := lower(COALESCE(auth.jwt()->>'email', '')) IN (
      'mohamedsabae50@gmail.com',
      'hackty65@gmail.com'
    )
    OR EXISTS (
      SELECT 1
      FROM public.profiles AS profile
      WHERE profile.user_id = auth.uid()
        AND lower(COALESCE(to_jsonb(profile)->>'is_admin', 'false')) = 'true'
    );
  IF NOT v_admin_allowed
    AND to_regclass('public.admin_users') IS NOT NULL
  THEN
    EXECUTE
      'SELECT EXISTS (SELECT 1 FROM public.admin_users WHERE user_id::text = $1::text)'
      INTO v_admin_allowed
      USING auth.uid();
  END IF;
  IF auth.uid() IS NULL OR NOT v_admin_allowed THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;

  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'target_user_id is required' USING ERRCODE = '22023';
  END IF;
  IF place_ids IS NULL
    OR cardinality(place_ids) = 0
    OR cardinality(place_ids) > 100
    OR EXISTS (
      SELECT 1
      FROM unnest(place_ids) AS requested(place_id)
      WHERE NULLIF(btrim(requested.place_id), '') IS NULL
         OR NOT EXISTS (
           SELECT 1 FROM public.places AS place
           WHERE place.id::text = requested.place_id
         )
    )
  THEN
    RAISE EXCEPTION 'Invalid place_ids' USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(NULLIF(profile.username, ''), 'Explorer')
  INTO v_profile_name
  FROM public.profiles AS profile
  WHERE profile.user_id = target_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Target profile not found' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.leaderboard (user_id, user_name)
  VALUES (target_user_id::text, v_profile_name)
  ON CONFLICT (user_id) DO NOTHING;

  PERFORM 1
  FROM public.leaderboard AS leaderboard
  WHERE leaderboard.user_id::text = target_user_id::text
  FOR UPDATE;

  INSERT INTO public.place_checkins (user_id, place_id, checked_in_at)
  SELECT target_user_id::text, requested.place_id, statement_timestamp()
  FROM (
    SELECT DISTINCT btrim(unnest(place_ids)) AS place_id
  ) AS requested
  ON CONFLICT (user_id, place_id) DO NOTHING;
  GET DIAGNOSTICS v_added = ROW_COUNT;

  SELECT
    count(*)::integer,
    count(*) FILTER (WHERE place.category = 'Historical')::integer,
    count(*) FILTER (WHERE place.category = 'Culture')::integer,
    count(*) FILTER (WHERE place.category = 'Food')::integer,
    count(*) FILTER (WHERE place.category = 'Nature')::integer
  INTO v_visit_count, v_historical, v_culture, v_food, v_nature
  FROM public.place_checkins AS checkin
  JOIN public.places AS place ON place.id::text = checkin.place_id::text
  WHERE checkin.user_id::text = target_user_id::text;

  SELECT COALESCE(
    CASE
      WHEN jsonb_typeof(leaderboard.badges) = 'array'
        THEN leaderboard.badges
      ELSE '[]'::jsonb
    END,
    '[]'::jsonb
  ), COALESCE(leaderboard.total_points, 0)
  INTO v_old_badges, v_total_xp
  FROM public.leaderboard AS leaderboard
  WHERE leaderboard.user_id::text = target_user_id::text;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', eligible.id,
        'name', eligible.name,
        'description', eligible.description,
        'icon_name', eligible.icon_name,
        'tier', eligible.tier,
        'earned_at', statement_timestamp()::text,
        'points_awarded', eligible.xp
      )
      ORDER BY eligible.id
    ),
    '[]'::jsonb
  )
  INTO v_new_badges
  FROM (VALUES
    ('first_steps', 'ach_first_steps_name', 'ach_first_steps_desc', 'flag_rounded', 'bronze', 50, v_visit_count >= 1),
    ('street_explorer', 'ach_street_explorer_name', 'ach_street_explorer_desc', 'explore_rounded', 'bronze', 100, v_visit_count >= 5),
    ('lore_master', 'ach_lore_master_name', 'ach_lore_master_desc', 'auto_stories_rounded', 'silver', 250, v_visit_count >= 15),
    ('alexandria_legend', 'ach_alexandria_legend_name', 'ach_alexandria_legend_desc', 'workspace_premium_rounded', 'gold', 500, v_visit_count >= 30),
    ('time_traveler', 'ach_time_traveler_name', 'ach_time_traveler_desc', 'history_edu_rounded', 'bronze', 150, v_historical >= 5),
    ('culture_vulture', 'ach_culture_vulture_name', 'ach_culture_vulture_desc', 'museum_rounded', 'silver', 150, v_culture >= 5),
    ('alex_foodie', 'ach_alex_foodie_name', 'ach_alex_foodie_desc', 'restaurant_rounded', 'bronze', 120, v_food >= 4),
    ('nature_lover', 'ach_nature_lover_name', 'ach_nature_lover_desc', 'park_rounded', 'bronze', 100, v_nature >= 3),
    ('social_explorer', 'ach_social_explorer_name', 'ach_social_explorer_desc', 'diversity_3_rounded', 'silver', 100, (
      SELECT count(*) >= 3
      FROM public.friendships AS friendship
      WHERE friendship.status = 'accepted'
        AND target_user_id IN (friendship.requester_id, friendship.recipient_id)
    ))
  ) AS eligible(id, name, description, icon_name, tier, xp, qualified)
  WHERE eligible.qualified
    AND NOT EXISTS (
      SELECT 1
      FROM jsonb_array_elements(v_old_badges) AS existing(value)
      WHERE existing.value->>'id' = eligible.id
    );

  v_all_badges := v_old_badges || v_new_badges;
  SELECT v_total_xp
      + (v_added * 50)
      + COALESCE(sum((badge.value->>'points_awarded')::integer), 0)
  INTO v_total_xp
  FROM jsonb_array_elements(v_new_badges) AS badge(value);

  UPDATE public.leaderboard
  SET places_visited = v_visit_count,
      total_points = v_total_xp,
      level = CASE
        WHEN v_total_xp >= 5000 THEN 'Lorekeeper'
        WHEN v_total_xp >= 2000 THEN 'Cartographer'
        WHEN v_total_xp >= 500 THEN 'Wanderer'
        ELSE 'Explorer'
      END,
      badges = v_all_badges,
      updated_at = statement_timestamp()
  WHERE user_id::text = target_user_id::text;

  UPDATE public.profiles
  SET xp = v_total_xp,
      badges = v_all_badges,
      updated_at = statement_timestamp()
  WHERE user_id = target_user_id;

  RETURN jsonb_build_object(
    'ok', true,
    'added_count', v_added,
    'places_visited', v_visit_count,
    'total_points', v_total_xp,
    'xp', v_total_xp,
    'badges', v_all_badges,
    'newly_unlocked', v_new_badges,
    'visited_place_ids', (
      SELECT COALESCE(
        jsonb_agg(checkin.place_id ORDER BY checkin.checked_in_at DESC),
        '[]'::jsonb
      )
      FROM public.place_checkins AS checkin
      WHERE checkin.user_id::text = target_user_id::text
    )
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_add_visits_and_sync(uuid, text[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_add_visits_and_sync(uuid, text[])
  TO authenticated;

-- ---------------------------------------------------------------------------
-- Coordinate safety: repair only unmistakably swapped lat/lng pairs and
-- update selected curated Alexandria locations from reviewed landmarks.
-- This leaves every unrelated/custom location row untouched.
-- ---------------------------------------------------------------------------
UPDATE public.places
SET lat = lng,
    lng = lat
WHERE lat BETWEEN 29.80 AND 30.10
  AND lng BETWEEN 31.10 AND 31.35
  AND lng BETWEEN 31.18 AND 31.32
  AND lat BETWEEN 29.88 AND 30.07;

UPDATE public.places AS place
SET lat = correction.lat,
    lng = correction.lng
FROM (VALUES
  ('Agami Beach', 31.1360829::double precision, 29.7813655::double precision),
  ('Citadel of Qaitbay', 31.2139::double precision, 29.8855::double precision),
  ('Bibliotheca Alexandrina', 31.2089::double precision, 29.9092::double precision),
  ('Pompey''s Pillar', 31.1825::double precision, 29.8967::double precision),
  ('Catacombs of Kom el Shoqafa', 31.1784::double precision, 29.8928::double precision),
  ('Montaza Palace Gardens', 31.2890::double precision, 30.0160::double precision),
  ('Alexandria National Museum', 31.1989::double precision, 29.9065::double precision),
  ('Graeco-Roman Museum', 31.1982::double precision, 29.9027::double precision),
  ('Roman Amphitheatre (Kom el-Dikka)', 31.1925::double precision, 29.9045::double precision),
  ('Stanley Bridge & Corniche', 31.2389::double precision, 29.9553::double precision),
  ('Royal Jewelry Museum', 31.2494::double precision, 29.9665::double precision),
  ('Cavafy Museum', 31.1984::double precision, 29.9018::double precision)
) AS correction(name, lat, lng)
WHERE lower(COALESCE(to_jsonb(place)->>'name_en', place.name))
    = lower(correction.name);

-- Review any remaining out-of-area entries before changing them; this query
-- intentionally reports rather than overwrites custom place coordinates.
SELECT id, name, lat, lng
FROM public.places
WHERE lat IS NULL
   OR lng IS NULL
   OR lat NOT BETWEEN 31.18 AND 31.32
   OR lng NOT BETWEEN 29.88 AND 30.07
ORDER BY name;
