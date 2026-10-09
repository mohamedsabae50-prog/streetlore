ALTER TABLE public.tours
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'published';

ALTER TABLE public.places
  ADD COLUMN IF NOT EXISTS image_urls text[] NOT NULL DEFAULT '{}';

UPDATE public.places
SET image_urls = ARRAY[image_url]
WHERE image_url IS NOT NULL
  AND image_url <> ''
  AND (image_urls IS NULL OR image_urls = '{}'::text[]);

ALTER TABLE public.tours
  DROP CONSTRAINT IF EXISTS tours_status_check;

ALTER TABLE public.tours
  ADD CONSTRAINT tours_status_check
  CHECK (status IN ('draft', 'published'));

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
  t.status
FROM public.tours t;
