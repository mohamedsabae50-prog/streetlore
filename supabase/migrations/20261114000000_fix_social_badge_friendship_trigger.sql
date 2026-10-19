CREATE OR REPLACE FUNCTION public.sync_social_explorer_badges()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
          END
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
$$;
