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
  v_category text;
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
    v_category := CASE
      WHEN v_suggestion.category = ANY (
        ARRAY[
          'Historical', 'Culture', 'Nature', 'Food',
          'Shopping', 'Mosques', 'Churches', 'Streets'
        ]::text[]
      ) THEN v_suggestion.category
      ELSE 'Culture'
    END;

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
      v_category,
      coalesce(v_suggestion.category_ar, v_category),
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
