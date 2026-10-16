-- ============================================================================
-- Migration: refund_ai_quota — hand a Gemini quota unit back on failure
--
-- ai-proxy consumes one unit (public.consume_ai_quota) before it calls Gemini.
-- When Gemini is down or rejects the request, the user got an error AND lost a
-- unit of their daily allowance (3/day free, 50/day Pro). The Edge Function now
-- calls this function exactly once in that case.
--
-- Rules:
--   - decrements today's usage by 1, never below 0;
--   - only touches the current Africa/Cairo day (same calendar as
--     consume_ai_quota): a unit taken just before midnight and refunded just
--     after it belongs to a window that is already over, so nothing changes;
--   - returns true when a unit was actually handed back;
--   - service_role only — a client must never be able to give itself quota.
--
-- Admins never consume quota, so ai-proxy never refunds for them either.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.refund_ai_quota(p_user_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now timestamptz := clock_timestamp();
  v_today date := (clock_timestamp() AT TIME ZONE 'Africa/Cairo')::date;
  refunded_rows integer;
BEGIN
  UPDATE public.ai_quota
  SET used_today = used_today - 1,
      updated_at = v_now
  WHERE user_id = p_user_id
    AND used_today > 0
    AND (window_start AT TIME ZONE 'Africa/Cairo')::date = v_today;

  GET DIAGNOSTICS refunded_rows = ROW_COUNT;
  RETURN refunded_rows > 0;
END;
$$;

REVOKE ALL ON FUNCTION public.refund_ai_quota(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refund_ai_quota(text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refund_ai_quota(text) TO service_role;
