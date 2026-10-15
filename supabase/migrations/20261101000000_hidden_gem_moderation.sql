ALTER TABLE public.suggested_places
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'Other',
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS name_ar text,
  ADD COLUMN IF NOT EXISTS category_ar text;

ALTER TABLE public.suggested_places ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage suggested places"
  ON public.suggested_places;
CREATE POLICY "Admins can manage suggested places"
  ON public.suggested_places
  FOR ALL
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  )
  WITH CHECK (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

GRANT SELECT, INSERT ON public.suggested_places TO authenticated;
GRANT UPDATE, DELETE ON public.suggested_places TO authenticated;

CREATE OR REPLACE FUNCTION public.moderate_hidden_gem(
  p_suggestion_id uuid,
  p_action text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_suggestion public.suggested_places%ROWTYPE;
  v_place_id text;
BEGIN
  IF lower(coalesce(auth.jwt() ->> 'email', '')) <>
     lower('mohamedsabae50@gmail.com') THEN
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
$$;

REVOKE ALL ON FUNCTION public.moderate_hidden_gem(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.moderate_hidden_gem(uuid, text)
  TO authenticated;
