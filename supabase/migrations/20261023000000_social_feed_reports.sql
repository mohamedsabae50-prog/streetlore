CREATE TABLE IF NOT EXISTS public.reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_id text NOT NULL CHECK (char_length(btrim(target_id)) > 0),
  target_type text NOT NULL
    CHECK (target_type IN ('place', 'user', 'review')),
  reason text NOT NULL
    CHECK (reason IN ('Inappropriate content', 'Spam', 'Harassment', 'False information', 'Other')),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'dismissed', 'resolved')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reports_pending_created_idx
  ON public.reports(created_at DESC)
  WHERE status = 'pending';

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users can submit reports" ON public.reports;
CREATE POLICY "users can submit reports"
  ON public.reports
  FOR INSERT
  TO authenticated
  WITH CHECK (reporter_id = auth.uid() AND status = 'pending');

DROP POLICY IF EXISTS "users can read own reports" ON public.reports;
CREATE POLICY "users can read own reports"
  ON public.reports
  FOR SELECT
  TO authenticated
  USING (reporter_id = auth.uid());

DROP POLICY IF EXISTS "admins can read reports" ON public.reports;
CREATE POLICY "admins can read reports"
  ON public.reports
  FOR SELECT
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

DROP POLICY IF EXISTS "admins can update reports" ON public.reports;
CREATE POLICY "admins can update reports"
  ON public.reports
  FOR UPDATE
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  )
  WITH CHECK (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

GRANT INSERT, SELECT ON public.reports TO authenticated;
GRANT UPDATE ON public.reports TO authenticated;

CREATE OR REPLACE FUNCTION public.get_pending_reports(p_limit integer DEFAULT 100)
RETURNS TABLE(
  id uuid,
  reporter_id uuid,
  reporter_username text,
  target_id text,
  target_type text,
  target_context text,
  reason text,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF lower(coalesce(auth.jwt() ->> 'email', '')) <>
     lower('mohamedsabae50@gmail.com') THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    report.id,
    report.reporter_id,
    reporter.username,
    report.target_id,
    report.target_type,
    CASE report.target_type
      WHEN 'place' THEN COALESCE(place.name, 'Place')
      WHEN 'user' THEN COALESCE('@' || target_profile.username, 'User')
      WHEN 'review' THEN 'Review'
    END,
    report.reason,
    report.status,
    report.created_at
  FROM public.reports AS report
  LEFT JOIN public.profiles AS reporter ON reporter.user_id = report.reporter_id
  LEFT JOIN public.places AS place
    ON report.target_type = 'place' AND place.id::text = report.target_id
  LEFT JOIN public.profiles AS target_profile
    ON report.target_type = 'user'
    AND target_profile.user_id::text = report.target_id
  WHERE report.status = 'pending'
  ORDER BY report.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 200));
END;
$$;

REVOKE ALL ON FUNCTION public.get_pending_reports(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_pending_reports(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_following_activity(p_limit integer DEFAULT 50)
RETURNS TABLE(
  event_id text,
  event_type text,
  actor_id uuid,
  actor_username text,
  target_id text,
  title text,
  description text,
  occurred_at timestamptz
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
    SELECT follows.following_id
    FROM public.user_follows AS follows
    WHERE follows.follower_id = auth.uid()
  ),
  activities AS (
    SELECT
      'checkin:' || checkins.id::text AS event_id,
      'checkin'::text AS event_type,
      checkins.user_id AS actor_id,
      profile.username AS actor_username,
      checkins.place_id AS target_id,
      COALESCE(places.name, checkins.place_id) AS title,
      'Checked in at a place'::text AS description,
      checkins.checked_in_at AS occurred_at
    FROM public.place_checkins AS checkins
    JOIN followed_users ON followed_users.following_id = checkins.user_id
    LEFT JOIN public.profiles AS profile ON profile.user_id = checkins.user_id
    LEFT JOIN public.places AS places ON places.id = checkins.place_id

    UNION ALL

    SELECT
      'badge:' || leaderboard.user_id::text || ':' || (badge->>'id'),
      'badge'::text,
      leaderboard.user_id,
      profile.username,
      COALESCE(badge->>'id', ''),
      COALESCE(badge->>'name', badge->>'id', 'Achievement'),
      COALESCE(badge->>'description', 'Unlocked an achievement'),
      COALESCE(
        NULLIF(badge->>'earned_at', '')::timestamptz,
        leaderboard.updated_at
      )
    FROM public.leaderboard AS leaderboard
    JOIN followed_users ON followed_users.following_id = leaderboard.user_id
    JOIN public.profiles AS profile ON profile.user_id = leaderboard.user_id
    CROSS JOIN LATERAL jsonb_array_elements(
      COALESCE(leaderboard.badges, '[]'::jsonb)
    ) AS badge

    UNION ALL

    SELECT
      'suggestion:' || suggestions.id::text,
      'suggestion'::text,
      suggestions.user_id,
      profile.username,
      suggestions.id::text,
      suggestions.title,
      suggestions.description,
      suggestions.created_at
    FROM public.suggested_places AS suggestions
    JOIN followed_users ON followed_users.following_id = suggestions.user_id
    JOIN public.profiles AS profile ON profile.user_id = suggestions.user_id
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
    activities.occurred_at
  FROM activities
  WHERE activities.actor_username IS NOT NULL
  ORDER BY activities.occurred_at DESC NULLS LAST
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
END;
$$;

REVOKE ALL ON FUNCTION public.get_following_activity(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_following_activity(integer) TO authenticated;
