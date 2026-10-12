CREATE TABLE IF NOT EXISTS public.ai_chat_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_prompt text NOT NULL,
  ai_response text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ai_chat_logs_created_at_idx
  ON public.ai_chat_logs (created_at DESC);

ALTER TABLE public.ai_chat_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admins can read ai chat logs" ON public.ai_chat_logs;
CREATE POLICY "admins can read ai chat logs"
  ON public.ai_chat_logs
  FOR SELECT
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

REVOKE ALL ON public.ai_chat_logs FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.ai_chat_logs TO authenticated;
GRANT INSERT ON public.ai_chat_logs TO service_role;
