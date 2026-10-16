ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS target_context text;

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
      WHEN 'ai_message' THEN coalesce(
        nullif(left(btrim(report.target_context), 2000), ''),
        'AI response'
      )
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
