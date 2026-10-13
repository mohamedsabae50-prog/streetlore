-- ============================================================================
-- Migration: ai_quota — per-user Gemini proxy rate limiting (PR #3)
-- Purpose: the old client-side Gemini keys were leaked; we now route
-- every AI request through the `ai-proxy` Edge Function which reads
-- GEMINI_API_KEY from the function's secrets. This table enforces a
-- fair daily quota per signed-in user so a single account can't burn
-- the entire project's API budget.
--
-- Default: 60 requests per rolling 24-hour window per user. Admins
-- are exempt (see the bypass in the Edge Function).
--
-- Run this once in Supabase SQL editor:
--   https://supabase.com/dashboard/project/tbivoxyxclwjjspwsgvc/sql/new
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.ai_quota (
  user_id       text   PRIMARY KEY,
  daily_limit   int    NOT NULL DEFAULT 60,
  used_today    int    NOT NULL DEFAULT 0,
  window_start  timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_quota_window_start
  ON public.ai_quota(window_start);

-- RLS: only the row's user_id can read or write their own counter.
-- The ai-proxy Edge Function uses the service_role key, which bypasses
-- RLS entirely. We expose a SELECT for clients that want to show
-- remaining quota, but no INSERT/UPDATE.
ALTER TABLE public.ai_quota ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ai_quota owner select"  ON public.ai_quota;
DROP POLICY IF EXISTS "ai_quota owner update"  ON public.ai_quota;

CREATE POLICY "ai_quota owner select"
  ON public.ai_quota
  FOR SELECT
  TO authenticated
  USING (user_id::text = auth.uid()::text);

-- No INSERT/UPDATE policies on purpose. The Edge Function holds the
-- service_role key and is the single point of mutation for this table.

-- Helpful view: how many requests each user has made today.
CREATE OR REPLACE VIEW public.ai_quota_today AS
  SELECT
    user_id,
    daily_limit,
    used_today,
    GREATEST(daily_limit - used_today, 0) AS remaining,
    window_start,
    updated_at
  FROM public.ai_quota;

GRANT SELECT ON public.ai_quota_today TO authenticated;

-- Sanity check
SELECT
  'ai_quota' AS table_name,
  COUNT(*)   AS row_count
FROM public.ai_quota;