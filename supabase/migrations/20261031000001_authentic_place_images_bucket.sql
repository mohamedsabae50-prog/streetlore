INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'place-images',
  'place-images',
  true,
  20971520,
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Public can read place images" ON storage.objects;
CREATE POLICY "Public can read place images"
  ON storage.objects
  FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'place-images');
