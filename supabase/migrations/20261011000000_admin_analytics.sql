ALTER TABLE public.tours
  ADD COLUMN IF NOT EXISTS view_count bigint NOT NULL DEFAULT 0;

ALTER TABLE public.tours
  DROP CONSTRAINT IF EXISTS tours_view_count_check;

ALTER TABLE public.tours
  ADD CONSTRAINT tours_view_count_check CHECK (view_count >= 0);

CREATE OR REPLACE VIEW public.tours_with_places AS
SELECT
  t.id,
  t.title,
  t.title_ar,
  t.description,
  t.description_ar,
  t.duration,
  t.duration_ar,
  t.category,
  t.category_ar,
  t.image_url,
  t.created_at,
  t.updated_at,
  COALESCE(
    (
      SELECT json_agg(
        json_build_object(
          'id', p.id,
          'name', p.name,
          'description', p.description,
          'imageUrl', p.image_url,
          'image_urls', p.image_urls,
          'rating', p.rating,
          'category', p.category,
          'lat', p.lat,
          'lng', p.lng,
          'address', p.address,
          'openHours', p.open_hours,
          'reviewCount', p.review_count,
          'priceLevel', p.price_level,
          'priceNote', p.price_note,
          'priceLocalEgp', p.price_local_egp,
          'priceForeignerEgp', p.price_foreigner_egp,
          'isHiddenGem', p.is_hidden_gem,
          'isFeatured', p.is_featured
        )
        ORDER BY tp.position
      )
      FROM public.tour_places tp
      JOIN public.places p ON p.id = tp.place_id
      WHERE tp.tour_id = t.id
    ),
    '[]'::json
  ) AS places,
  t.status,
  t.view_count
FROM public.tours t;

CREATE OR REPLACE FUNCTION public.increment_tour_view(p_tour_id text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $function$
  UPDATE public.tours
  SET view_count = view_count + 1
  WHERE id = p_tour_id
    AND status = 'published';
$function$;

REVOKE ALL ON FUNCTION public.increment_tour_view(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_tour_view(text)
  TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_admin_analytics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF lower(coalesce(auth.jwt() ->> 'email', '')) <>
     lower('mohamedsabae50@gmail.com') THEN
    RAISE EXCEPTION 'Admin access required'
      USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'total_ai_guide_usage',
    coalesce((SELECT sum(used_today) FROM public.ai_quota), 0),
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
    )
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_admin_analytics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_analytics() TO authenticated;
