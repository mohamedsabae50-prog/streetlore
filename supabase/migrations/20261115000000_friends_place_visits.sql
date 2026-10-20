UPDATE public.places
SET lat = 31.2049930,
    lng = 29.9439405
WHERE id::text = '51'
  AND name = 'Alexandria Zoo';

UPDATE public.places
SET lat = 31.2123848,
    lng = 29.8840544
WHERE id::text = '53'
  AND name = 'Alexandria Aquarium';

CREATE OR REPLACE FUNCTION public.get_friends_place_visits()
RETURNS TABLE (
  place_id text,
  friend_id uuid,
  username text,
  full_name text,
  avatar_url text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT DISTINCT
    checkins.place_id::text,
    friend.user_id,
    friend.username,
    COALESCE(
      NULLIF(btrim(to_jsonb(friend)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(friend)->>'display_name'), ''),
      ''
    ),
    friend.avatar_url
  FROM public.friendships AS friendship
  JOIN public.place_checkins AS checkins
    ON checkins.user_id = CASE
      WHEN friendship.requester_id = auth.uid()
        THEN friendship.recipient_id
      ELSE friendship.requester_id
    END
  JOIN public.profiles AS friend
    ON friend.user_id = checkins.user_id
  WHERE auth.uid() IS NOT NULL
    AND friendship.status = 'accepted'
    AND auth.uid() IN (friendship.requester_id, friendship.recipient_id)
    AND public.can_view_user_activity(friend.user_id::text)
  ORDER BY checkins.place_id::text, friend.username;
$$;

REVOKE ALL ON FUNCTION public.get_friends_place_visits()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_friends_place_visits()
  TO authenticated;
