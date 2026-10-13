-- Replace the legacy bucket-wide authenticated delete grant with owner-scoped
-- deletion for app uploads and a dedicated admin moderation policy.
DROP POLICY IF EXISTS "auth delete place-images" ON storage.objects;
DROP POLICY IF EXISTS "owner delete place-images" ON storage.objects;
CREATE POLICY "owner delete place-images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'place-images'
    AND name LIKE 'user-photos/%'
    AND owner_id = auth.uid()::text
  );

DROP POLICY IF EXISTS "admin can delete place-images" ON storage.objects;
CREATE POLICY "admin can delete place-images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'place-images'
    AND lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

-- Keep photo-row moderation available to the same admin account.
DROP POLICY IF EXISTS "admin can delete place_photos" ON public.place_photos;
CREATE POLICY "admin can delete place_photos"
  ON public.place_photos
  FOR DELETE
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );
