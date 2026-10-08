-- Keep the mobile and Admin place-feature flags on the same schema.
ALTER TABLE public.places
  ADD COLUMN IF NOT EXISTS enable_chat boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS enable_gallery boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS enable_photo_upload boolean NOT NULL DEFAULT true;

-- User-submitted photos are rows in place_photos and image objects in the
-- existing public place-images bucket used by the Admin panel.
CREATE TABLE IF NOT EXISTS public.place_photos (
  id text PRIMARY KEY,
  place_id text NOT NULL REFERENCES public.places(id) ON DELETE CASCADE,
  user_id text,
  user_name text NOT NULL DEFAULT 'Traveler',
  image_url text NOT NULL DEFAULT '',
  caption text NOT NULL DEFAULT '',
  caption_en text NOT NULL DEFAULT '',
  caption_ar text NOT NULL DEFAULT '',
  likes integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.place_photos
  ADD COLUMN IF NOT EXISTS place_id text,
  ADD COLUMN IF NOT EXISTS user_id text,
  ADD COLUMN IF NOT EXISTS user_name text NOT NULL DEFAULT 'Traveler',
  ADD COLUMN IF NOT EXISTS image_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS caption text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS caption_en text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS caption_ar text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS likes integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_place_photos_place_created
  ON public.place_photos(place_id, created_at DESC);

ALTER TABLE public.place_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read place_photos" ON public.place_photos;
CREATE POLICY "Public read place_photos"
  ON public.place_photos
  FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Owner insert place_photos" ON public.place_photos;
CREATE POLICY "Owner insert place_photos"
  ON public.place_photos
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id IS NOT NULL AND user_id::text = auth.uid()::text);

INSERT INTO storage.buckets (id, name, public)
VALUES ('place-images', 'place-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "public read place-images" ON storage.objects;
CREATE POLICY "public read place-images"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'place-images');

DROP POLICY IF EXISTS "auth upload place-images" ON storage.objects;
CREATE POLICY "auth upload place-images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'place-images');

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'places'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.places;
  END IF;
END;
$$;
