ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.protect_profile_admin_flag()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  IF coalesce(auth.jwt() ->> 'role', '') <> 'service_role'
     AND auth.uid() IS NOT NULL THEN
    IF TG_OP = 'INSERT' THEN
      NEW.is_admin := false;
    ELSE
      NEW.is_admin := OLD.is_admin;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.protect_profile_admin_flag()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS protect_profile_admin_flag_insert ON public.profiles;
CREATE TRIGGER protect_profile_admin_flag_insert
  BEFORE INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_profile_admin_flag();

DROP TRIGGER IF EXISTS protect_profile_admin_flag_update ON public.profiles;
CREATE TRIGGER protect_profile_admin_flag_update
  BEFORE UPDATE OF is_admin ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_profile_admin_flag();

CREATE TABLE IF NOT EXISTS public.admin_users (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_users FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.admin_users TO service_role;

INSERT INTO public.admin_users (user_id)
SELECT id
FROM auth.users
WHERE lower(email) = 'mohamedsabae50@gmail.com'
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.profiles (user_id, is_pro, updated_at, is_admin)
SELECT id, false, now(), true
FROM auth.users
WHERE lower(email) = 'mohamedsabae50@gmail.com'
ON CONFLICT (user_id) DO UPDATE
SET is_admin = true,
    updated_at = now();

DO $block$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM auth.users
    WHERE lower(email) = 'mohamedsabae50@gmail.com'
  ) THEN
    RAISE EXCEPTION
      'Cannot provision admin: mohamedsabae50@gmail.com is not in auth.users';
  END IF;
END;
$block$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT auth.uid() IS NOT NULL
    AND (
      lower(coalesce(auth.jwt() ->> 'email', '')) =
        'mohamedsabae50@gmail.com'
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

CREATE OR REPLACE FUNCTION public.get_admin_analytics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'total_ai_guide_usage',
    coalesce(
      (
        SELECT sum(used_today)
        FROM public.ai_quota
        WHERE (window_start AT TIME ZONE 'Africa/Cairo')::date =
          (statement_timestamp() AT TIME ZONE 'Africa/Cairo')::date
      ),
      0
    ),
    'total_checkins',
    (SELECT count(*) FROM public.place_checkins),
    'popular_tours',
    coalesce(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', popular.id,
            'title', popular.title,
            'view_count', popular.view_count
          )
          ORDER BY popular.view_count DESC, popular.title
        )
        FROM (
          SELECT id, title, view_count
          FROM public.tours
          WHERE status = 'published'
          ORDER BY view_count DESC, title
          LIMIT 5
        ) AS popular
      ),
      '[]'::jsonb
    ),
    'top_places_by_checkins',
    coalesce(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'place_id', popular.place_id,
            'place_name', popular.place_name,
            'checkin_count', popular.checkin_count
          )
          ORDER BY popular.checkin_count DESC, popular.place_name
        )
        FROM (
          SELECT
            checkins.place_id,
            coalesce(nullif(places.name, ''), checkins.place_id) AS place_name,
            count(*) AS checkin_count
          FROM public.place_checkins AS checkins
          LEFT JOIN public.places AS places
            ON places.id = checkins.place_id
          GROUP BY checkins.place_id, places.name
          ORDER BY count(*) DESC, place_name
          LIMIT 5
        ) AS popular
      ),
      '[]'::jsonb
    )
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_admin_analytics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_admin_analytics() TO authenticated;

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

REVOKE ALL ON FUNCTION public.get_pending_reports(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_pending_reports(integer) TO authenticated;

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

DROP POLICY IF EXISTS "Admins can manage suggested places"
  ON public.suggested_places;
CREATE POLICY "Admins can manage suggested places"
  ON public.suggested_places
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Users can submit pending suggested places"
  ON public.suggested_places;
CREATE POLICY "Users can submit pending suggested places"
  ON public.suggested_places
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND status = 'pending'
  );

DROP POLICY IF EXISTS "Users can read their suggested places"
  ON public.suggested_places;
CREATE POLICY "Users can read their suggested places"
  ON public.suggested_places
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "authenticated can read approved suggestions"
  ON public.suggested_places;
CREATE POLICY "authenticated can read approved suggestions"
  ON public.suggested_places
  FOR SELECT
  TO authenticated
  USING (status = 'approved');

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.suggested_places TO authenticated;

CREATE OR REPLACE FUNCTION public.set_suggested_place_defaults()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  NEW.user_id := coalesce(NEW.user_id, auth.uid());
  NEW.status := coalesce(nullif(NEW.status, ''), 'pending');
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS set_suggested_place_defaults
  ON public.suggested_places;
CREATE TRIGGER set_suggested_place_defaults
  BEFORE INSERT ON public.suggested_places
  FOR EACH ROW
  EXECUTE FUNCTION public.set_suggested_place_defaults();

CREATE OR REPLACE FUNCTION public.moderate_hidden_gem(
  p_suggestion_id uuid,
  p_action text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_suggestion public.suggested_places%ROWTYPE;
  v_place_id text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only an administrator can moderate suggestions'
      USING ERRCODE = '42501';
  END IF;

  IF p_action IS NULL OR p_action NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Unsupported moderation action: %', p_action
      USING ERRCODE = '22023';
  END IF;

  SELECT *
    INTO v_suggestion
    FROM public.suggested_places
   WHERE id = p_suggestion_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hidden gem suggestion % was not found', p_suggestion_id
      USING ERRCODE = 'P0002';
  END IF;
  IF v_suggestion.status <> 'pending' THEN
    RAISE EXCEPTION 'Hidden gem suggestion is already %', v_suggestion.status
      USING ERRCODE = '55000';
  END IF;

  IF p_action = 'approve' THEN
    v_place_id := 'suggestion-' || v_suggestion.id::text;
    INSERT INTO public.places (
      id, name, name_en, name_ar, description, description_en,
      category, category_ar, lat, lng, address, image_url, image_urls,
      is_hidden_gem, is_featured, rating, review_count, price_level,
      price_note, display_order, enable_chat, enable_gallery
    )
    VALUES (
      v_place_id,
      v_suggestion.title,
      v_suggestion.title,
      v_suggestion.name_ar,
      v_suggestion.description,
      v_suggestion.description,
      v_suggestion.category,
      coalesce(v_suggestion.category_ar, v_suggestion.category),
      v_suggestion.lat,
      v_suggestion.lng,
      v_suggestion.address,
      coalesce(v_suggestion.image_url, ''),
      CASE WHEN nullif(v_suggestion.image_url, '') IS NULL
        THEN ARRAY[]::text[]
        ELSE ARRAY[v_suggestion.image_url]
      END,
      true,
      false,
      0,
      0,
      'free',
      '',
      coalesce((SELECT max(display_order) FROM public.places), 0) + 1,
      false,
      false
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;

  UPDATE public.suggested_places
     SET status = CASE p_action
       WHEN 'approve' THEN 'approved'
       ELSE 'rejected'
     END
   WHERE id = p_suggestion_id;

  RETURN CASE WHEN p_action = 'approve' THEN v_place_id ELSE NULL END;
END;
$function$;

REVOKE ALL ON FUNCTION public.moderate_hidden_gem(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.moderate_hidden_gem(uuid, text)
  TO authenticated;

INSERT INTO storage.buckets (id, name, public)
VALUES ('place-images', 'place-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "public read place-images" ON storage.objects;
DROP POLICY IF EXISTS "Public can read place images" ON storage.objects;
DROP POLICY IF EXISTS "auth upload place-images" ON storage.objects;
DROP POLICY IF EXISTS "auth update place-images" ON storage.objects;
DROP POLICY IF EXISTS "auth delete place-images" ON storage.objects;
DROP POLICY IF EXISTS "owner delete place-images" ON storage.objects;
DROP POLICY IF EXISTS "admin can delete place-images" ON storage.objects;
DROP POLICY IF EXISTS "admin can insert place-images" ON storage.objects;
DROP POLICY IF EXISTS "admin can update place-images" ON storage.objects;
DROP POLICY IF EXISTS "admin can delete place-images objects" ON storage.objects;
DROP POLICY IF EXISTS place_images_admin_insert ON storage.objects;
DROP POLICY IF EXISTS place_images_admin_update ON storage.objects;
DROP POLICY IF EXISTS place_images_admin_delete ON storage.objects;

CREATE POLICY "Public can read place images"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'place-images');

CREATE POLICY "Admins can insert place images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'place-images' AND public.is_admin());

CREATE POLICY "Admins can update place images"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'place-images' AND public.is_admin())
  WITH CHECK (bucket_id = 'place-images' AND public.is_admin());

CREATE POLICY "Admins can delete place images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'place-images' AND public.is_admin());

DO $block$
DECLARE
  failed_image_url constant text :=
    'https://tbivoxyxclwjjspwsgvc.supabase.co/storage/v1/object/public/place-images/place-photos/ph_1792038266368_p0.jpg';
BEGIN
  UPDATE public.places
  SET image_url = CASE
        WHEN image_url = failed_image_url THEN ''
        ELSE image_url
      END,
      image_urls = array_remove(
        coalesce(image_urls, ARRAY[]::text[]),
        failed_image_url
      ),
      updated_at = now()
  WHERE image_url = failed_image_url
     OR image_urls @> ARRAY[failed_image_url]::text[];
END;
$block$;
