DROP POLICY IF EXISTS "Users can upload own place photos" ON storage.objects;
CREATE POLICY "Users can upload own place photos"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'place-images'
    AND (storage.foldername(name))[1] = 'user-photos'
    AND (storage.foldername(name))[2] = auth.uid()::text
    AND (storage.foldername(name))[3] <> ''
    AND name ~ '^user-photos/[^/]+/[^/]+/[^/]+$'
  );

DROP POLICY IF EXISTS "Users can update own place photos" ON storage.objects;
CREATE POLICY "Users can update own place photos"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'place-images'
    AND (storage.foldername(name))[1] = 'user-photos'
    AND (storage.foldername(name))[2] = auth.uid()::text
  )
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

DROP POLICY IF EXISTS "Owner insert place_photos" ON public.place_photos;
CREATE POLICY "Owner insert place_photos"
  ON public.place_photos
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id IS NOT NULL
    AND user_id::text = auth.uid()::text
  );

DROP POLICY IF EXISTS "Owner update own place_photos" ON public.place_photos;
CREATE POLICY "Owner update own place_photos"
  ON public.place_photos
  FOR UPDATE
  TO authenticated
  USING (user_id::text = auth.uid()::text)
  WITH CHECK (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS "Owner delete own place_photos" ON public.place_photos;
CREATE POLICY "Owner delete own place_photos"
  ON public.place_photos
  FOR DELETE
  TO authenticated
  USING (user_id::text = auth.uid()::text);
