DO $block$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM auth.users
    WHERE lower(btrim(email)) = 'mohamedsabae50@gmail.com'
  ) THEN
    RAISE EXCEPTION
      'Cannot provision admin: mohamedsabae50@gmail.com is not in auth.users';
  END IF;
END;
$block$;

INSERT INTO public.admin_users (user_id)
SELECT id
FROM auth.users
WHERE lower(btrim(email)) = 'mohamedsabae50@gmail.com'
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.profiles (user_id, is_pro, updated_at, is_admin)
SELECT id, false, now(), true
FROM auth.users
WHERE lower(btrim(email)) = 'mohamedsabae50@gmail.com'
ON CONFLICT (user_id) DO UPDATE
SET is_admin = true,
    updated_at = now();

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT auth.uid() IS NOT NULL
    AND (
      lower(btrim(coalesce(auth.jwt() ->> 'email', ''))) IN (
        'mohamedsabae50@gmail.com',
        'hackty65@gmail.com'
      )
      OR EXISTS (
        SELECT 1
        FROM public.admin_users AS admins
        WHERE admins.user_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1
        FROM public.profiles AS profile
        WHERE profile.user_id = auth.uid()
          AND profile.is_admin IS TRUE
      )
    );
$function$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, service_role;

DROP POLICY IF EXISTS "admins can read reports" ON public.reports;
CREATE POLICY "admins can read reports"
  ON public.reports
  FOR SELECT
  TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS "admins can update reports" ON public.reports;
CREATE POLICY "admins can update reports"
  ON public.reports
  FOR UPDATE
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

REVOKE ALL ON FUNCTION public.get_pending_reports(integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_pending_reports(integer)
  TO authenticated;

ALTER TABLE public.place_checkins
  DROP CONSTRAINT IF EXISTS place_checkins_user_id_fkey;
ALTER TABLE public.place_checkins
  ADD CONSTRAINT place_checkins_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;
