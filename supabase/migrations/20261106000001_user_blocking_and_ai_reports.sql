ALTER TABLE public.reports
  DROP CONSTRAINT IF EXISTS reports_target_type_check;

ALTER TABLE public.reports
  ADD CONSTRAINT reports_target_type_check
  CHECK (target_type IN ('place', 'user', 'review', 'ai_message'));

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
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
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
      WHEN 'place' THEN coalesce(place.name, 'Place')
      WHEN 'user' THEN coalesce('@' || target_profile.username, 'User')
      WHEN 'review' THEN 'Review'
      WHEN 'ai_message' THEN 'AI response'
    END,
    report.reason,
    report.status,
    report.created_at
  FROM public.reports AS report
  LEFT JOIN public.profiles AS reporter
    ON reporter.user_id = report.reporter_id
  LEFT JOIN public.places AS place
    ON report.target_type = 'place'
    AND place.id::text = report.target_id
  LEFT JOIN public.profiles AS target_profile
    ON report.target_type = 'user'
    AND target_profile.user_id::text = report.target_id
  WHERE report.status = 'pending'
  ORDER BY report.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 200));
END;
$function$;

CREATE TABLE IF NOT EXISTS public.blocked_users (
  blocker_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_user_id),
  CHECK (blocker_id <> blocked_user_id)
);

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.blocked_users FROM PUBLIC, anon;
GRANT SELECT, INSERT, DELETE ON public.blocked_users TO authenticated;

DROP POLICY IF EXISTS "Users can read their blocks" ON public.blocked_users;
CREATE POLICY "Users can read their blocks"
  ON public.blocked_users
  FOR SELECT
  TO authenticated
  USING (blocker_id = auth.uid());

DROP POLICY IF EXISTS "Users can block other users" ON public.blocked_users;
CREATE POLICY "Users can block other users"
  ON public.blocked_users
  FOR INSERT
  TO authenticated
  WITH CHECK (
    blocker_id = auth.uid()
    AND blocked_user_id <> auth.uid()
  );

DROP POLICY IF EXISTS "Users can unblock other users" ON public.blocked_users;
CREATE POLICY "Users can unblock other users"
  ON public.blocked_users
  FOR DELETE
  TO authenticated
  USING (blocker_id = auth.uid());

CREATE INDEX IF NOT EXISTS blocked_users_blocked_user_idx
  ON public.blocked_users(blocked_user_id);
