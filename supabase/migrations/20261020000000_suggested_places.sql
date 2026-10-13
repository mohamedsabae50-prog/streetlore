CREATE TABLE IF NOT EXISTS public.suggested_places (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL CHECK (char_length(trim(title)) > 0),
  description text NOT NULL CHECK (char_length(trim(description)) > 0),
  lat double precision NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng double precision NOT NULL CHECK (lng BETWEEN -180 AND 180),
  image_url text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_suggested_places_user_created
  ON public.suggested_places(user_id, created_at DESC);

ALTER TABLE public.suggested_places ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their suggested places"
  ON public.suggested_places;
CREATE POLICY "Users can read their suggested places"
  ON public.suggested_places
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can submit pending suggested places"
  ON public.suggested_places;
CREATE POLICY "Users can submit pending suggested places"
  ON public.suggested_places
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid() AND status = 'pending');

REVOKE ALL ON public.suggested_places FROM anon;
GRANT SELECT, INSERT ON public.suggested_places TO authenticated;

INSERT INTO storage.buckets (id, name, public)
VALUES ('suggestions', 'suggestions', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Authenticated users can upload suggestion images"
  ON storage.objects;
CREATE POLICY "Authenticated users can upload suggestion images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'suggestions'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can remove their suggestion images"
  ON storage.objects;
CREATE POLICY "Users can remove their suggestion images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'suggestions'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
