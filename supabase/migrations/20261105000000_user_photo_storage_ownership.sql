-- Community photo ownership in the `place-images` bucket.
--
-- 20261102000000 left `public.is_admin()` as the only role allowed to write to
-- `place-images`, which broke community photo uploads for every non-admin. The
-- app now uploads to `user-photos/<auth uid>/<place id>/<photo id>.jpg`; this
-- migration lets a user write and delete only inside their own folder.
--
-- It also pins `place_photos.image_url` for non-admins to an object in that
-- same folder. Account deletion (service_role) derives storage paths from
-- these rows, so an unchecked URL let one user point a row at an official
-- image and have it removed when their account was deleted.
--
-- The bucket's size and MIME limits (20261031000001) are not touched here.
-- The admin policies from 20261102000000 stay as they are. Existing rows are
-- not rewritten. Re-running this file is safe.

DROP POLICY IF EXISTS "Users can upload own place photos" ON storage.objects;
CREATE POLICY "Users can upload own place photos"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'place-images'
    AND (storage.foldername(name))[1] = 'user-photos'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can delete own place photos" ON storage.objects;
CREATE POLICY "Users can delete own place photos"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'place-images'
    AND (storage.foldername(name))[1] = 'user-photos'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

CREATE OR REPLACE FUNCTION public.enforce_place_photo_ownership()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid text := auth.uid()::text;
  v_marker constant text := '/storage/v1/object/public/place-images/';
  v_path text;
BEGIN
  -- No JWT subject means service_role, the SQL editor or a migration; admins
  -- may write any row. Everyone else is a regular signed-in user.
  IF v_uid IS NULL OR public.is_admin() THEN
    RETURN NEW;
  END IF;

  -- Like counts are never client-supplied. The app does not sync likes.
  IF TG_OP = 'INSERT' THEN
    NEW.likes := 0;
  ELSE
    NEW.likes := OLD.likes;
  END IF;

  -- The display name cannot impersonate the official accounts (those names
  -- are what the app and 20261104000000 treat as admin placeholders).
  NEW.user_name := left(btrim(coalesce(NEW.user_name, '')), 80);
  IF lower(NEW.user_name) IN ('', 'admin', 'streetlore', 'streetlore admin') THEN
    NEW.user_name := 'Traveler';
  END IF;

  IF TG_OP = 'INSERT' OR NEW.image_url IS DISTINCT FROM OLD.image_url THEN
    -- Must be the public URL of an object inside the caller's own
    -- `user-photos/<uid>/` folder. Plain path characters only, so a
    -- percent-encoded or `..` path cannot resolve to someone else's file.
    -- `data:` URLs are rejected here too; the app uploads first and only
    -- ever sends the resulting storage URL.
    IF NEW.image_url IS NULL
       OR NEW.image_url !~ (
         '^https?://[^/?#[:space:]]+' || v_marker || 'user-photos/' || v_uid
         || '/[A-Za-z0-9._~-]+(/[A-Za-z0-9._~-]+)*$'
       )
       OR NEW.image_url ~ '/\.{1,2}(/|$)'
    THEN
      RAISE EXCEPTION
        'place_photos.image_url must be the public URL of an object in your own user-photos folder'
        USING ERRCODE = '42501';
    END IF;

    v_path := substring(
      NEW.image_url FROM strpos(NEW.image_url, v_marker) + length(v_marker)
    );
    IF NOT EXISTS (
      SELECT 1
        FROM storage.objects AS stored
       WHERE stored.bucket_id = 'place-images'
         AND stored.name = v_path
    ) THEN
      RAISE EXCEPTION
        'place_photos.image_url does not point to an uploaded object'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.enforce_place_photo_ownership()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS enforce_place_photo_ownership ON public.place_photos;
CREATE TRIGGER enforce_place_photo_ownership
  BEFORE INSERT OR UPDATE ON public.place_photos
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_place_photo_ownership();
