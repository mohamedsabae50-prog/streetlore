ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS username text;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_lower_unique
  ON public.profiles (lower(username))
  WHERE username IS NOT NULL;

CREATE OR REPLACE FUNCTION public.set_my_username(p_username text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  clean_username text := btrim(p_username);
  current_username text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING errcode = '42501';
  END IF;

  IF clean_username !~ '^[A-Za-z0-9][A-Za-z0-9._-]{2,19}$' THEN
    RAISE EXCEPTION 'Username must be 3-20 characters and use letters, numbers, dots, underscores, or hyphens'
      USING errcode = '22023';
  END IF;

  SELECT profile.username
  INTO current_username
  FROM public.profiles AS profile
  WHERE profile.user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found' USING errcode = 'P0002';
  END IF;
  IF current_username IS NOT NULL THEN
    IF lower(current_username) = lower(clean_username) THEN
      RETURN true;
    END IF;
    RAISE EXCEPTION 'Username has already been set' USING errcode = '22023';
  END IF;

  UPDATE public.profiles
  SET username = clean_username,
      updated_at = now()
  WHERE user_id = auth.uid();

  RETURN true;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Username is already taken' USING errcode = '23505';
END;
$$;

REVOKE ALL ON FUNCTION public.set_my_username(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_my_username(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.search_users(p_query text, p_limit integer DEFAULT 30)
RETURNS TABLE(user_id uuid, username text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT profile.user_id, profile.username
  FROM public.profiles AS profile
  WHERE auth.uid() IS NOT NULL
    AND profile.username IS NOT NULL
    AND profile.user_id <> auth.uid()
    AND length(btrim(COALESCE(p_query, ''))) >= 2
    AND profile.username ILIKE '%' || btrim(p_query) || '%'
  ORDER BY profile.username
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50);
$$;

REVOKE ALL ON FUNCTION public.search_users(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_users(text, integer) TO authenticated;

CREATE TABLE IF NOT EXISTS public.user_follows (
  follower_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  following_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, following_id),
  CONSTRAINT user_follows_no_self_follow CHECK (follower_id <> following_id)
);

CREATE INDEX IF NOT EXISTS user_follows_following_id_idx
  ON public.user_follows (following_id, follower_id);

ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users can read their follows" ON public.user_follows;
CREATE POLICY "users can read their follows"
  ON public.user_follows
  FOR SELECT
  TO authenticated
  USING (auth.uid() = follower_id OR auth.uid() = following_id);

DROP POLICY IF EXISTS "users can follow from their own account" ON public.user_follows;
CREATE POLICY "users can follow from their own account"
  ON public.user_follows
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = follower_id AND follower_id <> following_id);

DROP POLICY IF EXISTS "users can unfollow from their own account" ON public.user_follows;
CREATE POLICY "users can unfollow from their own account"
  ON public.user_follows
  FOR DELETE
  TO authenticated
  USING (auth.uid() = follower_id);

GRANT SELECT, INSERT, DELETE ON public.user_follows TO authenticated;
