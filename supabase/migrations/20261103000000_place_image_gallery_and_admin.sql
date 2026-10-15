DO $block$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM auth.users
    WHERE lower(email) = 'hackty65@gmail.com'
  ) THEN
    RAISE EXCEPTION
      'Cannot provision admin: hackty65@gmail.com is not in auth.users';
  END IF;
END;
$block$;

INSERT INTO public.admin_users (user_id)
SELECT id
FROM auth.users
WHERE lower(email) = 'hackty65@gmail.com'
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.profiles (user_id, is_pro, updated_at, is_admin)
SELECT id, false, now(), true
FROM auth.users
WHERE lower(email) = 'hackty65@gmail.com'
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
      lower(coalesce(auth.jwt() ->> 'email', '')) IN (
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

DROP POLICY IF EXISTS "Allow admin delete" ON public.places;
DROP POLICY IF EXISTS "Allow admin insert" ON public.places;
DROP POLICY IF EXISTS "Allow admin update" ON public.places;
DROP POLICY IF EXISTS "admin can delete places" ON public.places;
DROP POLICY IF EXISTS "admin can insert places" ON public.places;
DROP POLICY IF EXISTS "admin can update places" ON public.places;
DROP POLICY IF EXISTS "auth write places" ON public.places;
DROP POLICY IF EXISTS "Allow public read" ON public.places;
DROP POLICY IF EXISTS "Allow public read access" ON public.places;
DROP POLICY IF EXISTS "public read places" ON public.places;
DROP POLICY IF EXISTS "places_admin_manage" ON public.places;
DROP POLICY IF EXISTS "places_public_read" ON public.places;

CREATE POLICY "places_admin_manage"
  ON public.places
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "places_public_read"
  ON public.places
  FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Allow admin delete" ON public.place_photos;
DROP POLICY IF EXISTS "Allow admin insert" ON public.place_photos;
DROP POLICY IF EXISTS "Allow admin update" ON public.place_photos;
DROP POLICY IF EXISTS "admin can delete place_photos" ON public.place_photos;
DROP POLICY IF EXISTS "admin can insert place_photos" ON public.place_photos;
DROP POLICY IF EXISTS "admin can select place_photos" ON public.place_photos;
DROP POLICY IF EXISTS "admin can update place_photos" ON public.place_photos;
DROP POLICY IF EXISTS "place_photos_admin_delete" ON public.place_photos;
DROP POLICY IF EXISTS "place_photos_admin_insert" ON public.place_photos;
DROP POLICY IF EXISTS "place_photos_admin_update" ON public.place_photos;
DROP POLICY IF EXISTS "place_photos_admin_manage" ON public.place_photos;
DROP POLICY IF EXISTS "Allow public read" ON public.place_photos;
DROP POLICY IF EXISTS "Public read place_photos" ON public.place_photos;
DROP POLICY IF EXISTS "place_photos_public_read" ON public.place_photos;
DROP POLICY IF EXISTS "Owner insert place_photos" ON public.place_photos;
DROP POLICY IF EXISTS "Owner update own place_photos" ON public.place_photos;
DROP POLICY IF EXISTS "Owner delete own place_photos" ON public.place_photos;
DROP POLICY IF EXISTS "Owner read place_photos" ON public.place_photos;

CREATE POLICY "place_photos_public_read"
  ON public.place_photos
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "place_photos_owner_insert"
  ON public.place_photos
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id IS NOT NULL AND user_id::text = auth.uid()::text);

CREATE POLICY "place_photos_owner_update"
  ON public.place_photos
  FOR UPDATE
  TO authenticated
  USING (user_id::text = auth.uid()::text)
  WITH CHECK (user_id::text = auth.uid()::text);

CREATE POLICY "place_photos_owner_delete"
  ON public.place_photos
  FOR DELETE
  TO authenticated
  USING (user_id::text = auth.uid()::text);

CREATE POLICY "place_photos_admin_manage"
  ON public.place_photos
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE OR REPLACE FUNCTION public.refresh_place_image_urls(
  p_place_id text,
  p_removed_photo_url text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_cover text;
  v_image_urls text[];
  v_merged_urls text[];
BEGIN
  SELECT place.image_url, place.image_urls
    INTO v_cover, v_image_urls
    FROM public.places AS place
   WHERE place.id = p_place_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF p_removed_photo_url IS NOT NULL
     AND nullif(btrim(v_cover), '') IS NOT DISTINCT FROM
       nullif(btrim(p_removed_photo_url), '') THEN
    v_cover := NULL;
  END IF;

  WITH candidates AS (
    SELECT nullif(btrim(v_cover), '') AS url, 0::bigint AS sort_order
    UNION ALL
    SELECT nullif(btrim(existing.url), ''), existing.ordinality
      FROM unnest(coalesce(v_image_urls, ARRAY[]::text[]))
        WITH ORDINALITY AS existing(url, ordinality)
     WHERE p_removed_photo_url IS NULL
        OR nullif(btrim(existing.url), '') IS DISTINCT FROM
          nullif(btrim(p_removed_photo_url), '')
        OR nullif(btrim(existing.url), '') IS NOT DISTINCT FROM
          nullif(btrim(v_cover), '')
    UNION ALL
    SELECT nullif(btrim(photo.image_url), ''),
           1000000 + row_number() OVER (
             ORDER BY photo.created_at, photo.id
           )
      FROM public.place_photos AS photo
     WHERE photo.place_id = p_place_id
  ),
  unique_urls AS (
    SELECT candidate.url, min(candidate.sort_order) AS sort_order
      FROM candidates AS candidate
     WHERE candidate.url IS NOT NULL
     GROUP BY candidate.url
  )
  SELECT coalesce(
    array_agg(unique_urls.url ORDER BY unique_urls.sort_order, unique_urls.url),
    ARRAY[]::text[]
  )
    INTO v_merged_urls
    FROM unique_urls;

  UPDATE public.places
     SET image_url = coalesce(v_merged_urls[1], ''),
         image_urls = v_merged_urls
   WHERE id = p_place_id
     AND (
       image_url IS DISTINCT FROM coalesce(v_merged_urls[1], '')
       OR image_urls IS DISTINCT FROM v_merged_urls
     );
END;
$function$;

REVOKE ALL ON FUNCTION public.refresh_place_image_urls(text, text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.sync_place_photo_gallery()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.refresh_place_image_urls(OLD.place_id, OLD.image_url);
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.place_id IS DISTINCT FROM NEW.place_id THEN
    PERFORM public.refresh_place_image_urls(OLD.place_id, OLD.image_url);
    PERFORM public.refresh_place_image_urls(NEW.place_id);
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND OLD.image_url IS DISTINCT FROM NEW.image_url THEN
    PERFORM public.refresh_place_image_urls(NEW.place_id, OLD.image_url);
  ELSE
    PERFORM public.refresh_place_image_urls(NEW.place_id);
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.sync_place_photo_gallery()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS sync_place_photo_gallery ON public.place_photos;
CREATE TRIGGER sync_place_photo_gallery
  AFTER INSERT OR UPDATE OR DELETE ON public.place_photos
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_place_photo_gallery();

WITH candidates AS (
  SELECT place.id AS place_id,
         nullif(btrim(place.image_url), '') AS url,
         0::bigint AS sort_order
    FROM public.places AS place
  UNION ALL
  SELECT place.id,
         nullif(btrim(existing.url), ''),
         existing.ordinality
    FROM public.places AS place
    CROSS JOIN LATERAL unnest(
      coalesce(place.image_urls, ARRAY[]::text[])
    ) WITH ORDINALITY AS existing(url, ordinality)
  UNION ALL
  SELECT photo.place_id,
         nullif(btrim(photo.image_url), ''),
         1000000 + row_number() OVER (
           PARTITION BY photo.place_id
           ORDER BY photo.created_at, photo.id
         )
    FROM public.place_photos AS photo
),
unique_urls AS (
  SELECT candidates.place_id,
         candidates.url,
         min(candidates.sort_order) AS sort_order
    FROM candidates
   WHERE candidates.url IS NOT NULL
   GROUP BY candidates.place_id, candidates.url
),
merged AS (
  SELECT unique_urls.place_id,
         array_agg(unique_urls.url ORDER BY unique_urls.sort_order, unique_urls.url)
           AS image_urls
    FROM unique_urls
   GROUP BY unique_urls.place_id
)
UPDATE public.places AS place
   SET image_urls = coalesce(merged.image_urls, ARRAY[]::text[]),
       image_url = coalesce(merged.image_urls[1], '')
  FROM merged
 WHERE place.id = merged.place_id
   AND (
     place.image_urls IS DISTINCT FROM merged.image_urls
     OR place.image_url IS DISTINCT FROM coalesce(merged.image_urls[1], '')
   );

CREATE OR REPLACE FUNCTION public.force_update_display_orders(
  p_place_ids text[],
  p_new_orders int[]
)
RETURNS TABLE (updated_id text, updated_order int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_expected_count int;
  v_actual_count int;
  v_missing_ids text[];
  v_duplicate_ids text[];
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: admin access required'
      USING ERRCODE = '42501';
  END IF;

  v_expected_count := array_length(p_place_ids, 1);
  IF v_expected_count IS NULL OR v_expected_count = 0 THEN
    RAISE EXCEPTION 'force_update_display_orders: place_ids is empty'
      USING ERRCODE = '22023';
  END IF;
  IF v_expected_count <> array_length(p_new_orders, 1) THEN
    RAISE EXCEPTION
      'force_update_display_orders: array length mismatch (ids=%, orders=%)',
      v_expected_count, array_length(p_new_orders, 1)
      USING ERRCODE = '22023';
  END IF;

  SELECT array_agg(duplicate.id_value)
    INTO v_duplicate_ids
    FROM (
      SELECT input.id_value
        FROM unnest(p_place_ids) AS input(id_value)
       GROUP BY input.id_value
      HAVING count(*) > 1
    ) AS duplicate;
  IF v_duplicate_ids IS NOT NULL THEN
    RAISE EXCEPTION 'force_update_display_orders: duplicate place ids: %',
      v_duplicate_ids USING ERRCODE = '22023';
  END IF;

  UPDATE public.places AS place
     SET display_order = input.new_order
    FROM unnest(p_place_ids, p_new_orders) AS input(id_value, new_order)
   WHERE place.id = input.id_value;
  GET DIAGNOSTICS v_actual_count = ROW_COUNT;

  IF v_actual_count <> v_expected_count THEN
    SELECT array_agg(input.id_value)
      INTO v_missing_ids
      FROM unnest(p_place_ids) AS input(id_value)
     WHERE NOT EXISTS (
       SELECT 1
         FROM public.places AS place
        WHERE place.id = input.id_value
     );
    RAISE EXCEPTION
      'force_update_display_orders: only % of % rows were updated (missing ids: %)',
      v_actual_count, v_expected_count, v_missing_ids
      USING ERRCODE = 'P0002';
  END IF;

  RETURN QUERY
    SELECT place.id, place.display_order
      FROM public.places AS place
     WHERE place.id = ANY(p_place_ids)
     ORDER BY array_position(p_place_ids, place.id);
END;
$function$;

REVOKE ALL ON FUNCTION public.force_update_display_orders(text[], int[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.force_update_display_orders(text[], int[])
  TO authenticated;
